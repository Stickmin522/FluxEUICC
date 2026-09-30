package im.angry.openeuicc.ui

import android.content.pm.PackageManager
import android.icu.text.ListFormatter
import android.os.Build
import android.os.Bundle
import android.se.omapi.Reader
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.os.ConfigurationCompat
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.google.android.material.color.MaterialColors
import im.angry.easyeuicc.R
import im.angry.openeuicc.util.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

open class QuickCompatibilityFragment : Fragment(), UnprivilegedEuiccContextMarker {
    companion object {
        enum class Compatibility {
            COMPATIBLE,
            UNCONFIRMED,
            NOT_COMPATIBLE,
        }

        data class CompatibilityResult(
            val compatibility: Compatibility,
            val omapiConnected: Boolean = false,
            val usbHost: Boolean = false,
            val slotsOmapi: List<String> = emptyList(),
            val slotsIsdr: List<String> = emptyList()
        )
    }

    private val conclusion: TextView by lazy {
        requireView().requireViewById(R.id.quick_compatibility_conclusion)
    }

    private val resultSlots: TextView by lazy {
        requireView().requireViewById(R.id.quick_compatibility_result_slots)
    }

    private val resultSlotsIsdr: TextView by lazy {
        requireView().requireViewById(R.id.quick_compatibility_result_slots_isdr)
    }

    private val resultNotes: TextView by lazy {
        requireView().requireViewById(R.id.quick_compatibility_result_notes)
    }

    private val skipCheckBox: CheckBox by lazy {
        requireView().requireViewById(R.id.quick_compatibility_skip)
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View = inflater.inflate(R.layout.fragment_quick_compatibility, container, false).apply {
        requireViewById<TextView>(R.id.quick_compatibility_device_information)
            .text = formatDeviceInformation()
        requireViewById<Button>(R.id.quick_compatibility_button_continue)
            .setOnClickListener { onContinueToApp() }
        // Can't use the lazy field yet
        requireViewById<CheckBox>(R.id.quick_compatibility_skip).setOnCheckedChangeListener { compoundButton, b ->
            if (compoundButton.isVisible) {
                runBlocking {
                    preferenceRepository.skipQuickCompatibilityFlow
                        .updatePreference(b)
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        lifecycleScope.launch {
            onCompatibilityUpdate(withContext(Dispatchers.IO) {
                getCompatibilityCheckResult()
            })
        }
    }

    private fun onContinueToApp() {
        requireActivity().finish()
    }

    private fun onCompatibilityUpdate(result: CompatibilityResult) {
        conclusion.text = formatConclusion(result)
        val checks = requireView().requireViewById<LinearLayout>(R.id.quick_compatibility_checks)
        checks.removeAllViews()
        addCheck(checks, R.string.quick_compatibility_check_omapi, result.omapiConnected)
        addCheck(checks, R.string.quick_compatibility_check_sim_slot, result.slotsOmapi.isNotEmpty())
        addCheck(checks, R.string.quick_compatibility_check_isdr, result.slotsIsdr.isNotEmpty(),
            result.slotsOmapi.isNotEmpty())
        addCheck(checks, R.string.quick_compatibility_check_usb_host, result.usbHost)
        addCheck(checks, R.string.quick_compatibility_check_ara_m, false, true)

        val listFormatter = ListFormatter.getInstance(
            ConfigurationCompat.getLocales(resources.configuration).get(0)
        )
        resultSlots.isVisible = result.slotsOmapi.isNotEmpty()
        if (result.slotsOmapi.isNotEmpty()) {
            resultSlots.text = getString(
                R.string.quick_compatibility_result_slots,
                listFormatter.format(result.slotsOmapi),
            )
        }
        resultSlotsIsdr.isVisible = result.slotsIsdr.isNotEmpty()
        if (result.slotsIsdr.isNotEmpty()) {
            resultSlotsIsdr.text = getString(
                R.string.quick_compatibility_result_slots_isdr,
                listFormatter.format(result.slotsIsdr),
            )
        }
        resultNotes.isVisible = true
        resultNotes.text = if (result.compatibility == Compatibility.COMPATIBLE) {
            getString(R.string.quick_compatibility_check_explanation)
        } else {
            getString(R.string.quick_compatibility_check_explanation) + "\n\n" +
                getString(R.string.quick_compatibility_result_notes_incompatible)
        }
        if (result.compatibility == Compatibility.COMPATIBLE) {
            // Don't show the message again, ever, if the result is compatible
            runBlocking {
                preferenceRepository.skipQuickCompatibilityFlow
                    .updatePreference(true)
            }
        } else {
            skipCheckBox.isVisible = true
        }
    }

    private fun addCheck(parent: LinearLayout, labelId: Int, supported: Boolean, unknown: Boolean = false) {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density + 0.5f).toInt()
        val row = LinearLayout(requireContext()).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL
            minimumHeight = dp(44)
        }
        row.addView(TextView(requireContext()).apply {
            setText(labelId)
            textSize = 14f
            setTextColor(MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface))
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        row.addView(TextView(requireContext()).apply {
            text = if (supported) "✓" else if (unknown) "—" else "×"
            textSize = 20f
            setTextColor(MaterialColors.getColor(this,
                if (supported) android.R.attr.colorAccent
                else com.google.android.material.R.attr.colorOnSurfaceVariant))
            contentDescription = getString(
                if (supported) R.string.quick_compatibility_status_supported
                else if (unknown) R.string.quick_compatibility_status_not_verified
                else R.string.quick_compatibility_status_not_detected,
            )
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            marginStart = dp(16)
        })
        parent.addView(row)
    }

    private suspend fun getCompatibilityCheckResult(): CompatibilityResult {
        val usbHost = requireContext().packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
        val service = connectSEService(requireContext())
        if (!service.isConnected) {
            return CompatibilityResult(Compatibility.NOT_COMPATIBLE, usbHost = usbHost)
        }
        val readers = service.readers.filter(Reader::isSIM)
        val omapiSlots = readers.mapNotNull(Reader::slotIndex)
        val slots = readers.mapNotNull { reader ->
            try {
                // Note: we ONLY check the default ISD-R AID, because this test is for the _device_,
                // NOT the eUICC. We don't care what AID a potential eUICC might use, all we need to
                // check is we can open _some_ AID.
                val session = reader.openSession()
                try {
                    val channel = session.openLogicalChannel(EUICC_DEFAULT_ISDR_AID.decodeHex())
                    channel?.close()
                    if (channel == null) null else reader.slotIndex
                } finally {
                    session.close()
                }
            } catch (_: SecurityException) {
                // Ignore; this is expected when everything works
                // ref: https://android.googlesource.com/platform/frameworks/base/+/4fe64fb4712a99d5da9c9a0eb8fd5169b252e1e1/omapi/java/android/se/omapi/Session.java#305
                // SecurityException is only thrown when Channel is constructed, which means everything else needs to succeed
                reader.slotIndex
            } catch (_: Exception) {
                null
            }
        }
        if (omapiSlots.isEmpty()) {
            return CompatibilityResult(Compatibility.NOT_COMPATIBLE,
                omapiConnected = true, usbHost = usbHost)
        }
        val formatChannelName = appContainer.customizableTextProvider::formatNonUsbChannelName
        return CompatibilityResult(
            if (slots.isNotEmpty()) Compatibility.COMPATIBLE else Compatibility.UNCONFIRMED,
            omapiConnected = true,
            usbHost = usbHost,
            slotsOmapi = omapiSlots.map(formatChannelName),
            slotsIsdr = slots.map(formatChannelName),
        )
    }

    open fun formatConclusion(result: CompatibilityResult): String {
        val usbHost = requireContext().packageManager
            .hasSystemFeature(PackageManager.FEATURE_USB_HOST)
        val resId = when (result.compatibility) {
            Compatibility.COMPATIBLE ->
                R.string.quick_compatibility_compatible

            Compatibility.UNCONFIRMED ->
                R.string.quick_compatibility_unconfirmed

            Compatibility.NOT_COMPATIBLE -> if (usbHost)
                R.string.quick_compatibility_not_compatible_but_usb else
                R.string.quick_compatibility_not_compatible
        }
        return getString(resId, "OpenEUICC")
    }

    open fun formatDeviceInformation() = buildString {
        appendLine("BRAND: ${Build.BRAND}")
        appendLine("DEVICE: ${Build.DEVICE}")
        appendLine("MODEL: ${Build.MODEL}")
        appendLine("VERSION.RELEASE: ${Build.VERSION.RELEASE}")
        appendLine("VERSION.SDK_INT: ${Build.VERSION.SDK_INT}")
        val carrier = getSystemProperty("ro.carrier")
        if (carrier != "unknown") appendLine("CARRIER: $carrier")
    }
}

private inline val Reader.isSIM: Boolean
    get() = name.startsWith("SIM")

private inline val Reader.slotIndex: Int
    get() = (name.replace("SIM", "").toIntOrNull() ?: 1) - 1 // 0-based index

fun getSystemProperty(name: String): String =
    Runtime.getRuntime().exec(arrayOf("getprop", name))
        .inputStream.bufferedReader()
        .use { it.readLine() }.ifEmpty { "unknown" }
