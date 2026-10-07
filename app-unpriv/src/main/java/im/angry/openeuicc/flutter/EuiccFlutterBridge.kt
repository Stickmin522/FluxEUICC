package im.angry.openeuicc.flutter

import android.Manifest
import android.app.LocaleManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.LocaleList
import android.net.Uri
import android.telephony.TelephonyManager
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import androidx.core.net.toUri
import androidx.core.os.LocaleListCompat
import androidx.lifecycle.lifecycleScope
import im.angry.openeuicc.common.R
import im.angry.openeuicc.core.EuiccChannel
import im.angry.openeuicc.core.EuiccChannelManager
import im.angry.openeuicc.core.OmapiApduInterface
import im.angry.openeuicc.service.EuiccChannelManagerService
import im.angry.openeuicc.ui.wizard.DownloadWizardLowPowerFragment
import im.angry.openeuicc.ui.wizard.SimplifiedErrorMessages
import im.angry.openeuicc.util.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import net.typeblog.lpac_jni.*
import net.typeblog.lpac_jni.impl.PKID_GSMA_LIVE_CI
import net.typeblog.lpac_jni.impl.PKID_GSMA_TEST_CI
import org.json.JSONObject
import java.security.MessageDigest

class EuiccFlutterBridge(private val activity: FluxFlutterActivity) : EventChannel.StreamHandler {
    private val scope get() = activity.lifecycleScope
    private val prefs get() = activity.preferenceRepository
    private val manager get() = activity.euiccChannelManager
    private val service get() = activity.euiccChannelManagerService
    private val gate = Mutex()
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var taskJob: Job? = null
    private var lastTask: Map<String, Any?>? = null
    private var usbDevice: UsbDevice? = null
    private var usbPermission: CompletableDeferred<Boolean>? = null
    private var imageResult: CompletableDeferred<String?>? = null
    private var exportResult: CompletableDeferred<Boolean>? = null
    private var exportText = ""
    private var exportedUri: Uri? = null
    private val local = activity.getSharedPreferences("flutter_state", Context.MODE_PRIVATE)
    private val picker = activity.registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val pending = imageResult
        imageResult = null
        scope.launch {
            val result = withContext(Dispatchers.IO) {
                uri?.let {
                    runCatching {
                        activity.contentResolver.openInputStream(it)?.use { input ->
                            BitmapFactory.decodeStream(input)?.use(::decodeQrFromBitmap)
                        }
                    }.getOrNull()
                }
            }
            pending?.complete(result)
        }
    }
    private val exporter = activity.registerForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri ->
        val pending = exportResult
        exportResult = null
        val text = exportText
        exportText = ""
        scope.launch {
            val saved = withContext(Dispatchers.IO) {
                uri != null && runCatching {
                    activity.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
                        ?: error("Cannot open document")
                }.isSuccess
            }
            if (saved) exportedUri = uri
            pending?.complete(saved)
        }
    }
    private val permissions = activity.registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        emit(mapOf("type" to "refresh"))
    }
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == USB_PERMISSION) {
                usbPermission?.complete(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
            } else {
                emit(mapOf("type" to "refresh"))
            }
        }
    }

    init {
        ContextCompat.registerReceiver(activity, receiver, IntentFilter().apply {
            addAction(USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    fun attach(messenger: BinaryMessenger) {
        methods = MethodChannel(messenger, "im.fluxeuicc/control").also { channel ->
            channel.setMethodCallHandler { call, result ->
                scope.launch {
                    try {
                        result.success(dispatch(call))
                    } catch (e: CancellationException) {
                        result.error("interrupted", "Operation interrupted", null)
                        throw e
                    } catch (e: BridgeFailure) {
                        result.error(e.key, e.key, null)
                    } catch (_: Exception) {
                        result.error("operation_failed", "Operation failed", null)
                    }
                }
            }
        }
        events = EventChannel(messenger, "im.fluxeuicc/events").also { it.setStreamHandler(this) }
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        sink = eventSink
        lastTask?.let(::emit)
    }

    override fun onCancel(arguments: Any?) { sink = null }

    private fun emit(event: Map<String, Any?>) { sink?.success(event) }

    fun deliverIntent(intent: Intent) { emit(mapOf("type" to "intent", "intent" to intentData(intent))) }

    private fun intentData(intent: Intent): Map<String, Any?> = mapOf(
        "route" to (intent.getStringExtra("route") ?: when {
            intent.data != null -> "download"
            intent.component?.className?.contains("Download") == true -> "download"
            else -> "home"
        }),
        "lpa" to intent.data?.toString(),
        "slot" to intent.getIntExtra("selectedLogicalSlot", -1),
        "log" to intent.getStringExtra("log")?.let(::redactLog),
    )

    private suspend fun dispatch(call: MethodCall): Any? {
        val args = (call.arguments as? Map<*, *>) ?: emptyMap<Any, Any>()
        fun text(key: String) = args[key] as? String ?: ""
        return when (call.method) {
            "bootstrap" -> mapOf(
                "version" to activity.selfAppVersion,
                "fingerprint" to fingerprint(),
                "locale" to activity.resources.configuration.locales[0].toLanguageTag(),
                "language" to applicationLanguage(),
                "systemLocale" to systemLanguage(),
                "preferences" to preferenceValues(),
                "intent" to intentData(activity.intent),
                "pendingTask" to local.getLong("task", -1),
                "pendingKind" to local.getString("kind", ""),
                "skipCompatibility" to prefs.skipQuickCompatibilityFlow.first(),
                "lowBattery" to DownloadWizardLowPowerFragment.isBatteryLow(activity),
            )
            "permissions" -> {
                val required = mutableListOf(Manifest.permission.READ_PHONE_STATE)
                if (Build.VERSION.SDK_INT >= 33) required += Manifest.permission.POST_NOTIFICATIONS
                val missing = required.filter { ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED }
                if (missing.isNotEmpty()) permissions.launch(missing.toTypedArray())
                null
            }
            "scan" -> cardAccess { scan() }
            "lowBattery" -> DownloadWizardLowPowerFragment.isBatteryLow(activity)
            "profiles" -> cardAccess { withCard(args) { cardData(it, profiles = true) } }
            "info" -> cardAccess { withCard(args) { info(it) } }
            "notifications" -> cardAccess {
                withCard(args) { channel ->
                    val names = channel.lpa.profiles.associate { it.iccid to it.displayName }
                    channel.lpa.notifications.map { notification -> mapOf(
                        "sequence" to notification.seqNumber,
                        "address" to notification.notificationAddress,
                        "iccid" to notification.iccid,
                        "name" to (names[notification.iccid] ?: notification.iccid),
                        "operation" to notification.profileManagementOperation.name.lowercase(),
                    ) }
                }
            }
            "notification" -> cardAccess {
                withCard(args) { channel ->
                    val seq = (args["sequence"] as Number).toLong()
                    val ok = if (args["delete"] == true) channel.lpa.deleteNotification(seq) else channel.lpa.handleNotification(seq)
                    if (!ok) throw BridgeFailure("operation_failed")
                }
            }
            "task" -> gate.withLock { startTask(args) }
            "recover" -> {
                activity.euiccChannelManagerLoaded.await()
                val id = (args["id"] as Number).toLong()
                val handle = service.recoverForegroundTaskSubscriber(id)
                if (handle == null) {
                    local.edit().remove("task").apply()
                    false
                } else {
                    observe(handle, local.getString("kind", "") ?: "")
                    true
                }
            }
            "confirm" -> {
                activity.euiccChannelManagerLoaded.await()
                val id = (args["id"] as Number).toLong()
                val handle = service.recoverForegroundTaskSubscriber(id) ?: throw BridgeFailure("interrupted")
                handle.backChannel.send(args["accepted"] == true)
                null
            }
            "parse" -> {
                val input = text("input")
                val lpa = if (input.startsWith("LPA:", true) || input.startsWith("1$")) input else {
                    val uri = input.toUri()
                    uri.queryParameterNames.flatMap(uri::getQueryParameters)
                        .firstOrNull { it.startsWith("LPA:1$", true) } ?: throw BridgeFailure("profile_download_incorrect_lpa_string_message")
                }
                val parsed = runCatching { LPAString.parse(lpa) }.getOrElse {
                    throw BridgeFailure("profile_download_incorrect_lpa_string_message")
                }
                mapOf("address" to parsed.address, "matchingId" to parsed.matchingId, "confirmationRequired" to parsed.confirmationCodeRequired)
            }
            "image" -> {
                if (imageResult != null) throw BridgeFailure("busy")
                val pending = CompletableDeferred<String?>()
                imageResult = pending
                picker.launch("image/*")
                pending.await()
            }
            "usbPermission" -> {
                val device = usbDevice ?: throw BridgeFailure("usb_failed")
                if (usbPermission != null) throw BridgeFailure("busy")
                val pending = CompletableDeferred<Boolean>()
                usbPermission = pending
                try {
                    activity.getSystemService(UsbManager::class.java).requestPermission(device,
                        PendingIntent.getBroadcast(activity, 0, Intent(USB_PERMISSION).setPackage(activity.packageName), PendingIntent.FLAG_IMMUTABLE))
                    withTimeout(60_000) { pending.await() }
                } finally { usbPermission = null }
            }
            "preferences" -> preferenceValues()
            "preference" -> { updatePreference(text("key"), args["value"]); preferenceValues() }
            "language" -> {
                val tag = text("tag")
                require(tag.isEmpty() || tag in SUPPORTED_LANGUAGES)
                AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))
                null
            }
            "compatibility" -> withContext(Dispatchers.IO) { compatibility() }
            "skipCompatibility" -> { prefs.skipQuickCompatibilityFlow.updatePreference(args["skip"] == true); null }
            "logs" -> redactLog(activity.intent.getStringExtra("log") ?: readSelfLog())
            "export" -> {
                if (exportResult != null) throw BridgeFailure("busy")
                val pending = CompletableDeferred<Boolean>()
                exportText = redactLog(text("text"))
                exportResult = pending
                exporter.launch("FluxEUICC-${System.currentTimeMillis()}.txt")
                pending.await()
            }
            "source" -> { activity.startActivity(Intent(Intent.ACTION_VIEW, "https://github.com/Stickmin522/FluxEUICC".toUri())); null }
            "shareExport" -> {
                val uri = exportedUri ?: throw BridgeFailure("operation_failed")
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    clipData = ClipData.newUri(activity.contentResolver, "FluxEUICC log", uri)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                activity.startActivity(Intent.createChooser(intent, null))
                null
            }
            "toolkit" -> {
                val slot = (args["slot"] as Number).toInt()
                val intent = SIMToolkit(activity)[slot] ?: throw BridgeFailure("operation_failed")
                activity.startActivity(intent)
                null
            }
            else -> throw BridgeFailure("unknown_method")
        }
    }

    private suspend fun <T> cardAccess(block: suspend () -> T): T = gate.withLock {
        activity.euiccChannelManagerLoaded.await()
        service.waitForForegroundTask()
        block()
    }

    private suspend fun <T> withCard(args: Map<*, *>, block: suspend (EuiccChannel) -> T): T {
        val slot = (args["slot"] as Number).toInt()
        val port = (args["port"] as Number).toInt()
        val se = EuiccChannel.SecureElementId.createFromInt((args["se"] as Number).toInt())
        return manager.withEuiccChannel(slot, port, se, block)
    }

    private suspend fun scan(): Map<String, Any?> {
        val (device, opened) = manager.tryOpenUsbEuiccChannel()
        usbDevice = device
        val cards = mutableListOf<Map<String, Any?>>()
        manager.flowAllOpenEuiccPorts().collect { (slot, port) ->
            manager.flowEuiccSecureElements(slot, port).collect { se ->
                manager.withEuiccChannel(slot, port, se) { cards += cardData(it, profiles = true) }
            }
        }
        activity.updateShortcuts()
        return mapOf("cards" to cards.sortedWith(compareBy(
            { it["usb"] == true }, { it["logicalSlot"] as Int }, { it["se"] as Int }
        )), "usb" to device?.let { mapOf(
            "name" to (it.productName ?: "USB CCID"), "opened" to opened,
            "permission" to activity.getSystemService(UsbManager::class.java).hasPermission(it),
        ) })
    }

    private suspend fun cardData(channel: EuiccChannel, profiles: Boolean = false): Map<String, Any?> {
        val cardProfiles = channel.lpa.profiles
        val active = cardProfiles.enabled
        val eid = channel.lpa.eID
        val reader = (channel.apduInterface as? OmapiApduInterface)?.readerName
        val systemSlot = if (reader != null) {
            SimSlotResolver.resolve(reader, systemSimSlots(), eid, active?.iccid)
        } else null
        val unfiltered = prefs.unfilteredProfileListFlow.first()
        val canDisable = channel.slotId == EuiccChannelManager.USB_CHANNEL_ID || prefs.disableSafeguardFlow.first()
        val title = when {
            channel.slotId == EuiccChannelManager.USB_CHANNEL_ID -> "USB"
            systemSlot != null -> "SIM ${systemSlot + 1}"
            else -> "eUICC"
        }
        return buildMap {
            put("slot", channel.slotId); put("port", channel.portId); put("se", channel.seId.id)
            put("logicalSlot", channel.logicalSlotId)
            put("systemSlot", systemSlot)
            put("title", title + if (channel.hasMultipleSE) " · SE ${channel.seId.id}" else "")
            put("eid", eid)
            put("active", active?.displayName)
            put("freeSpace", channel.lpa.euiccInfo2?.freeNvram?.let(::formatFreeSpace))
            put("usb", channel.slotId == EuiccChannelManager.USB_CHANNEL_ID)
            put("toolkit", SIMToolkit(activity)[channel.slotId] != null)
            if (profiles) put("profiles", (if (unfiltered) cardProfiles else cardProfiles.operational).map { mapOf(
                "iccid" to it.iccid, "name" to it.displayName, "provider" to it.providerName,
                "icon" to it.icon,
                "enabled" to it.isEnabled, "class" to it.profileClass.name,
                "showClass" to unfiltered,
                "canEnable" to (active == null || active.profileClass == it.profileClass),
                "canDisable" to canDisable,
            ) })
        }
    }

    private fun systemSimSlots(): List<SystemSimSlot> {
        if (Build.VERSION.SDK_INT < 29) return emptyList()
        return runCatching {
            activity.getSystemService(TelephonyManager::class.java).uiccCardsInfo.flatMap { card ->
                if (Build.VERSION.SDK_INT >= 33) {
                    card.ports.map { port ->
                        SystemSimSlot(card.physicalSlotIndex, port.logicalSlotIndex.takeIf { port.isActive },
                            card.eid, port.iccId)
                    }.ifEmpty { listOf(SystemSimSlot(card.physicalSlotIndex, null, card.eid)) }
                } else {
                    listOf(SystemSimSlot(card.physicalSlotIndex, null, card.eid, card.iccId))
                }
            }
        }.getOrDefault(emptyList())
    }

    private suspend fun startTask(args: Map<*, *>): Long {
        activity.euiccChannelManagerLoaded.await()
        if (taskJob?.isActive == true) throw BridgeFailure("busy")
        service.waitForForegroundTask()
        val kind = args["kind"] as String
        val slot = (args["slot"] as Number).toInt()
        val port = (args["port"] as Number).toInt()
        val se = EuiccChannel.SecureElementId.createFromInt((args["se"] as Number).toInt())
        val iccid = args["iccid"] as? String ?: ""
        val handle = when (kind) {
            "download" -> {
                val address = (args["address"] as String).trim()
                if (!validSmdpAddress(address)) throw BridgeFailure("invalid_address")
                val input = ProfileDownloadInput(address,
                    (args["matchingId"] as? String)?.trim()?.ifBlank { null },
                    (args["imei"] as? String)?.trim()?.ifBlank { null },
                    (args["confirmationCode"] as? String)?.trim()?.ifBlank { null })
                withCard(args) { require(it.valid) }
                service.launchProfileDownloadTask(slot, port, se, input)
            }
            "switch" -> {
                val enable = args["enable"] == true
                withCard(args) { channel ->
                    val profiles = channel.lpa.profiles
                    val profile = profiles.find { it.iccid == iccid } ?: throw BridgeFailure("download_wizard_slot_removed")
                    if (enable && profiles.enabled?.let { it.profileClass != profile.profileClass } == true)
                        throw BridgeFailure("toast_profile_enable_cross_class")
                    if (!enable && slot != EuiccChannelManager.USB_CHANNEL_ID && !prefs.disableSafeguardFlow.first())
                        throw BridgeFailure("safeguard_enabled")
                }
                service.launchProfileSwitchTask(slot, port, se, iccid, enable, 30_000)
            }
            "rename" -> service.launchProfileRenameTask(slot, port, se, iccid, args["name"] as String)
            "delete" -> {
                withCard(args) { channel ->
                    val profile = channel.lpa.profiles.find { it.iccid == iccid } ?: throw BridgeFailure("download_wizard_slot_removed")
                    if (profile.isEnabled || args["confirmation"] != profile.displayName)
                        throw BridgeFailure("toast_profile_delete_confirm_text_mismatched")
                }
                service.launchProfileDeleteTask(slot, port, se, iccid)
            }
            "reset" -> {
                withCard(args) { channel ->
                    val text = activity.getString(R.string.euicc_memory_reset_confirm_text, channel.lpa.eID.takeLast(8))
                    if (args["confirmation"] != text) throw BridgeFailure("toast_euicc_memory_reset_confirm_text_mismatched")
                    if (slot != EuiccChannelManager.USB_CHANNEL_ID && !prefs.disableSafeguardFlow.first())
                        throw BridgeFailure("safeguard_enabled")
                }
                service.launchMemoryReset(slot, port, se)
            }
            else -> throw BridgeFailure("unknown_method")
        }
        local.edit().putLong("task", handle.taskId).putString("kind", kind).apply()
        observe(handle, kind)
        return handle.taskId
    }

    private fun observe(handle: EuiccChannelManagerService.ForegroundTaskHandle, kind: String) {
        taskJob?.cancel()
        taskJob = scope.launch {
            if (kind == "download") activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            try {
                handle.stateFlow.first { state ->
                    val event = mutableMapOf<String, Any?>("type" to "task", "id" to handle.taskId, "kind" to kind)
                    when (state) {
                        EuiccChannelManagerService.ForegroundTaskState.Idle -> return@first false
                        is EuiccChannelManagerService.ForegroundTaskState.InProgress -> {
                            event["running"] = true
                            event["progress"] = state.progress
                            val context = state.context as? ProfileDownloadState
                            event["phase"] = context?.javaClass?.simpleName ?: "Preparing"
                            if (context is ProfileDownloadState.ConfirmingDownload) event["metadata"] = context.metadata?.let {
                                mapOf("name" to it.name, "provider" to it.providerName, "iccid" to it.iccid)
                            } ?: emptyMap<String, String>()
                        }
                        is EuiccChannelManagerService.ForegroundTaskState.Done -> {
                            event["running"] = false
                            event["error"] = when (state.error) {
                                null -> null
                                is EuiccChannelManagerService.SwitchingProfilesRefreshException -> "profile_switch_did_not_refresh"
                                is EuiccChannelManagerService.SwitchingProfilesReconnectException -> "profile_switch_pending_system"
                                is LocalProfileAssistant.ProfileNameTooLongException -> "profile_rename_too_long"
                                is LocalProfileAssistant.ProfileNameIsInvalidUTF8Exception -> "profile_rename_encoding_error"
                                else -> if (kind == "reset") "task_euicc_memory_reset_failure" else "task_profile_${kind}_failure"
                            }
                            event["warning"] = state.error is EuiccChannelManagerService.SwitchingProfilesRefreshException ||
                                state.error is EuiccChannelManagerService.SwitchingProfilesReconnectException
                            (state.error as? LocalProfileAssistant.ProfileDownloadException)?.let {
                                event["message"] = runCatching { SimplifiedErrorMessages.fromDownloadError(it) }.getOrNull().let { message ->
                                    (message?.titleResId?.let(activity::getString) ?: activity.getString(R.string.task_profile_download_failure)) + "\n" + (message?.suggestResId?.let(activity::getString) ?: "")
                                }
                                event["diagnostics"] = diagnostics(it)
                            }
                            local.edit().remove("task").apply()
                        }
                    }
                    lastTask = event
                    emit(event)
                    state is EuiccChannelManagerService.ForegroundTaskState.Done
                }
            } finally { activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
        }
    }

    private fun diagnostics(error: LocalProfileAssistant.ProfileDownloadException): String = redactLog(buildString {
        appendLine("Error code: ${error.lpaErrorReason}")
        error.lastHttpResponse?.let { response ->
            appendLine("HTTP status: ${response.rcode}")
            runCatching { JSONObject(response.data.decodeToString()).getJSONObject("header").getJSONObject("functionExecutionStatus") }
                .getOrNull()?.let { status ->
                    appendLine("Server status: ${status.optString("status")}")
                    status.optJSONObject("statusCodeData")?.let {
                        appendLine("Subject: ${it.optString("subjectCode")}; reason: ${it.optString("reasonCode")}")
                    }
                }
        }
        error.lastHttpException?.let { appendLine("HTTP exception: ${it.javaClass.simpleName}: ${it.message}") }
        error.lastApduResponse?.takeLast(2)?.toByteArray()?.let { appendLine("APDU status: ${it.encodeHex()}") }
        error.lastApduException?.let { appendLine("APDU exception: ${it.javaClass.simpleName}: ${it.message}") }
    })

    private fun info(channel: EuiccChannel): List<Map<String, String>> = buildList {
        fun item(key: String, value: String?) { value?.let { add(mapOf("key" to key, "value" to it)) } }
        item("euicc_info_access_mode", channel.type)
        item("euicc_info_removable", activity.getString(if (channel.port.card.isRemovable) R.string.euicc_info_yes else R.string.euicc_info_no))
        item("euicc_info_eid", channel.lpa.eID)
        item("euicc_info_isdr_aid", channel.isdrAid.encodeHex())
        channel.tryParseEuiccVendorInfo()?.let {
            item("euicc_info_sku", it.skuName); item("euicc_info_sn", it.serialNumber); item("euicc_info_fw_ver", it.firmwareVersion)
        }
        channel.lpa.euiccInfo2?.let {
            item("euicc_info_sgp22_version", it.sgp22Version.toString())
            item("euicc_info_sas_accreditation_number", it.sasAccreditationNumber)
            item("euicc_info_free_nvram", formatFreeSpace(it.freeNvram))
            val ci = when {
                PKID_GSMA_LIVE_CI.any(it.euiccCiPKIdListForSigning::contains) -> R.string.euicc_info_ci_gsma_live
                PKID_GSMA_TEST_CI.any(it.euiccCiPKIdListForSigning::contains) -> R.string.euicc_info_ci_gsma_test
                else -> R.string.euicc_info_ci_unknown
            }
            item("euicc_info_ci_type", activity.getString(ci))
        }
        item("euicc_info_atr", channel.atr?.encodeHex())
    }

    private suspend fun preferenceValues(): Map<String, Any> = mapOf(
        "notificationDownload" to prefs.notificationDownloadFlow.first(), "notificationDelete" to prefs.notificationDeleteFlow.first(),
        "notificationSwitch" to prefs.notificationSwitchFlow.first(), "disableSafeguard" to prefs.disableSafeguardFlow.first(),
        "verboseLogging" to prefs.verboseLoggingFlow.first(), "forceTpdu" to prefs.forceTpduModeFlow.first(),
        "httpProxy" to prefs.httpProxyFlow.first(), "developer" to prefs.developerOptionsEnabledFlow.first(),
        "refreshAfterSwitch" to prefs.refreshAfterSwitchFlow.first(), "unfiltered" to prefs.unfilteredProfileListFlow.first(),
        "ignoreTls" to prefs.ignoreTLSCertificateFlow.first(), "mss" to prefs.es10xMssFlow.first(), "aidList" to prefs.isdrAidListFlow.first(),
    )

    private suspend fun updatePreference(key: String, value: Any?) {
        when (key) {
            "notificationDownload" -> prefs.notificationDownloadFlow.updatePreference(value as Boolean)
            "notificationDelete" -> prefs.notificationDeleteFlow.updatePreference(value as Boolean)
            "notificationSwitch" -> prefs.notificationSwitchFlow.updatePreference(value as Boolean)
            "disableSafeguard" -> prefs.disableSafeguardFlow.updatePreference(value as Boolean)
            "verboseLogging" -> prefs.verboseLoggingFlow.updatePreference(value as Boolean)
            "forceTpdu" -> prefs.forceTpduModeFlow.updatePreference(value as Boolean)
            "httpProxy" -> prefs.httpProxyFlow.updatePreference(value as String)
            "developer" -> prefs.developerOptionsEnabledFlow.updatePreference(value as Boolean)
            "refreshAfterSwitch" -> prefs.refreshAfterSwitchFlow.updatePreference(value as Boolean)
            "unfiltered" -> prefs.unfilteredProfileListFlow.updatePreference(value as Boolean)
            "ignoreTls" -> prefs.ignoreTLSCertificateFlow.updatePreference(value as Boolean)
            "mss" -> { val mss = (value as Number).toInt(); require(mss == 63 || mss == 255); prefs.es10xMssFlow.updatePreference(mss) }
            "aidList" -> if (value == null) prefs.isdrAidListFlow.removePreference() else prefs.isdrAidListFlow.updatePreference(value as String)
            else -> throw BridgeFailure("unknown_method")
        }
    }

    private fun fingerprint(): String = activity.packageManager
        .getPackageInfo(activity.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        .signingInfo!!.apkContentsSigners.first().toByteArray()
        .let(MessageDigest.getInstance("SHA-1")::digest).encodeHex()

    private fun applicationLanguage(): String = AppCompatDelegate.getApplicationLocales().toLanguageTags()
    private fun systemLanguage(): String = if (Build.VERSION.SDK_INT >= 33)
        activity.getSystemService(LocaleManager::class.java).systemLocales[0]?.toLanguageTag() ?: "en-US"
    else android.content.res.Resources.getSystem().configuration.locales[0].toLanguageTag()

    private suspend fun compatibility(): Map<String, Any?> {
        val usb = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
        val omapi = connectSEService(activity)
        try {
            val readers = if (omapi.isConnected) omapi.readers.filter { it.name.startsWith("SIM") } else emptyList()
            val isdr = readers.mapNotNull { reader ->
                try {
                    val session = reader.openSession()
                    try {
                        session.openLogicalChannel(EUICC_DEFAULT_ISDR_AID.decodeHex())?.let { channel -> channel.close(); reader.name }
                    } finally { session.close() }
                } catch (_: SecurityException) { reader.name } catch (_: Exception) { null }
            }
            return mapOf("omapi" to omapi.isConnected, "readers" to readers.map { it.name }, "isdr" to isdr, "usb" to usb,
                "device" to "${Build.MANUFACTURER} ${Build.MODEL}\nAndroid ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        } finally { omapi.shutdown() }
    }

    fun close() {
        taskJob?.cancel()
        activity.unregisterReceiver(receiver)
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        sink = null
    }

    private class BridgeFailure(val key: String) : Exception(key)

    companion object {
        private const val USB_PERMISSION = "im.fluxeuicc.USB_PERMISSION"
        val SUPPORTED_LANGUAGES = setOf("en-US", "zh-CN", "zh-TW", "ja", "ko", "ar", "fr", "de", "es")

        fun validSmdpAddress(input: String): Boolean {
            val host = input.substringBeforeLast(':', input)
            if (input.contains(':') && input.substringAfterLast(':').toIntOrNull()?.let { it in 1..65535 } != true) return false
            return host.contains('.') && host.length <= 255 && host.split('.').all { part ->
                part.isNotEmpty() && part.length <= 63 && part.first() != '-' && part.last() != '-' && part.all { it.isLetterOrDigit() || it == '-' }
            }
        }
    }
}
