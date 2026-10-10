package im.angry.openeuicc.service

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Binder
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import im.angry.openeuicc.common.R
import im.angry.openeuicc.core.EuiccChannel
import im.angry.openeuicc.core.EuiccChannelManager
import im.angry.openeuicc.util.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.last
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.takeWhile
import kotlinx.coroutines.flow.transformWhile
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.yield
import net.typeblog.lpac_jni.ProfileDownloadInput
import net.typeblog.lpac_jni.ProfileDownloadState
import java.util.concurrent.atomic.AtomicLong

/**
 * An Android Service wrapper for EuiccChannelManager.
 * The purpose of this wrapper is mainly lifecycle-wise: having a Service allows the manager
 * instance to have its own independent lifecycle. This way it can be created as requested and
 * destroyed when no other components are bound to this service anymore.
 * This behavior allows us to avoid keeping the APDU channels open at all times. For example,
 * the EuiccService implementation should *only* bind to this service when it requires an
 * instance of EuiccChannelManager. UI components can keep being bound to this service for
 * their entire lifecycles, since the whole purpose of them is to expose the current state
 * to the user.
 *
 * Additionally, this service is also responsible for long-running "foreground" tasks that
 * are not suitable to be managed by UI components. This includes profile downloading, etc.
 * When a UI component needs to run one of these tasks, they have to bind to this service
 * and call one of the `launch*` methods, which will run the task inside this service's
 * lifecycle context and return a Flow instance for the UI component to subscribe to its
 * progress.
 */
// open so that tests can substitute fakes for the service (see DownloadTaskLauncherTest)
open class EuiccChannelManagerService : LifecycleService(), OpenEuiccContextMarker {
    companion object {
        private const val TAG = "EuiccChannelManagerService"
        private const val CHANNEL_ID = "tasks"
        private const val FOREGROUND_ID = 1000
        private const val TASK_FAILURE_ID = 1000

        /**
         * Utility function to wait for a foreground task to be done, return its
         * error if any, or null on success.
         */
        suspend fun Flow<ForegroundTaskState>.waitDone(): Throwable? =
            (this.last() as ForegroundTaskState.Done).error

        /**
         * Apply transform to a ForegroundTaskState flow so that it completes when a Done is seen.
         *
         * This must be applied each time a flow is returned for subscription purposes. If applied
         * beforehand, we lose the ability to subscribe multiple times.
         */
        private fun Flow<ForegroundTaskState>.applyCompletionTransform() =
            transformWhile {
                emit(it)
                it !is ForegroundTaskState.Done
            }
    }

    inner class LocalBinder : Binder() {
        val service = this@EuiccChannelManagerService
    }

    private val euiccChannelManagerDelegate = lazy {
        appContainer.euiccChannelManagerFactory.createEuiccChannelManager(this)
    }
    val euiccChannelManager: EuiccChannelManager by euiccChannelManagerDelegate

    private val wakeLock: PowerManager.WakeLock by lazy {
        (getSystemService(POWER_SERVICE) as PowerManager).run {
            newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, this::class.simpleName)
        }
    }

    /**
     * The state of a "foreground" task (named so due to the need to startForeground())
     */
    sealed interface ForegroundTaskState {
        data object Idle : ForegroundTaskState
        data class InProgress(val progress: Int, val context: Any? = null) : ForegroundTaskState
        data class Done(val error: Throwable?) : ForegroundTaskState
    }

    /**
     * This flow emits whenever the service has had a start command, from startService()
     * The service self-starts when foreground is required, because other components
     * only bind to this service and do not start it per-se.
     */
    private val foregroundStarted = MutableStateFlow(-1L)
    private val taskIds = AtomicLong(System.currentTimeMillis())

    /**
     * This flow is used to emit progress updates when a foreground task is running.
     */
    private val foregroundTaskState: MutableStateFlow<ForegroundTaskState> =
        MutableStateFlow(ForegroundTaskState.Idle)

    /**
     * Every handle represents a subscriber to a foreground task's state updates (via stateFlow),
     * and a way to back-communicate (via backChannel).
     *
     * taskId uniquely identifies a task within this service instance.
     */
    data class ForegroundTaskHandle(
        val taskId: Long,
        val stateFlow: Flow<ForegroundTaskState>,
        val backChannel: Channel<Any>
    )

    /**
     * Private record of an already launched foreground task. This is separate from
     * ForegroundTaskHandle, because we store the original SharedFlow directly.
     * This way, we can create new ForegroundTaskHandles by applying independent
     * but identical transforms on the original flow.
     */
    private data class ForegroundTaskRecord(
        val stateFlow: SharedFlow<ForegroundTaskState>,
        val backChannel: Channel<Any>
    )

    /**
     * A cache of subscribers to 5 recently-launched foreground tasks, identified by ID
     *
     * Only one can be run at the same time, but those that are done will be kept in this
     * map for a little while -- because UI components may be stopped and recreated while
     * tasks are running. Having this buffer allows the components to re-subscribe even if
     * the task completes while they are being recreated.
     */
    private val foregroundTaskRecords: MutableMap<Long, ForegroundTaskRecord> = mutableMapOf()
    private val operationLock = Mutex()
    private data class NotificationKey(val slotId: Int, val portId: Int, val seId: EuiccChannel.SecureElementId)
    private data class NotificationRequest(var afterSeq: Long, var failures: Int = 0, var generation: Int = 0)
    private val pendingNotifications = mutableMapOf<NotificationKey, NotificationRequest>()
    private var notificationJob: Job? = null

    override fun onBind(intent: Intent): IBinder {
        super.onBind(intent)
        return LocalBinder()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (euiccChannelManagerDelegate.isInitialized()) {
            euiccChannelManager.invalidate()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return super.onStartCommand(intent, flags, startId).also {
            foregroundStarted.value = intent?.getLongExtra("taskId", -1L) ?: -1L
        }
    }

    private fun ensureForegroundTaskNotificationChannel() {
        val nm = NotificationManagerCompat.from(this)
        if (nm.getNotificationChannelCompat(CHANNEL_ID) == null) {
            val channel =
                NotificationChannelCompat.Builder(
                    CHANNEL_ID,
                    NotificationManagerCompat.IMPORTANCE_LOW
                )
                    .setName(getString(R.string.task_notification))
                    .setVibrationEnabled(false)
                    .build()
            nm.createNotificationChannel(channel)
        }
    }

    private suspend fun updateForegroundNotification(title: String, iconRes: Int) {
        ensureForegroundTaskNotificationChannel()

        val nm = NotificationManagerCompat.from(this)
        val state = foregroundTaskState.value

        if (state is ForegroundTaskState.InProgress) {
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setProgress(100, state.progress, state.progress == 0)
                .setSmallIcon(iconRes)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build()

            if (state.progress == 0) {
                startForeground(FOREGROUND_ID, notification)
            } else if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                nm.notify(FOREGROUND_ID, notification)
            }

            // Yield out so that the main looper can handle the notification event
            // Without this yield, the notification sent above will not be shown in time.
            yield()
        } else if (notificationJob?.isActive == true) {
            startForeground(FOREGROUND_ID, NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(getString(R.string.profile_notifications))
                .setSmallIcon(R.drawable.ic_task_sim_card_download)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .build())
        } else {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private fun postForegroundTaskFailureNotification(title: String) {
        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(R.drawable.ic_x_black)
            .build()
        NotificationManagerCompat.from(this).notify(TASK_FAILURE_ID, notification)
    }

    /**
     * Recover the handle to a foreground task that is recently launched by creating a new subscriber.
     *
     * null if the task doesn't exist, or was launched too long ago.
     */
    fun recoverForegroundTaskSubscriber(taskId: Long): ForegroundTaskHandle? =
        foregroundTaskRecords[taskId]?.let {
            ForegroundTaskHandle(taskId, it.stateFlow.applyCompletionTransform(), it.backChannel)
        }

    /**
     * Launch a potentially blocking foreground task in this service's lifecycle context.
     * This function does not block, but returns a Flow that emits ForegroundTaskState
     * updates associated with this task. The last update the returned flow will emit is
     * always ForegroundTaskState.Done.
     *
     * The returned flow can only be subscribed to once even though the underlying implementation
     * is a SharedFlow. This is due to the need to apply transformations so that the stream
     * actually completes. In order to subscribe multiple times, use `recoverForegroundTaskSubscriber`
     * to acquire another instance.
     *
     * The task closure is expected to update foregroundTaskState whenever appropriate.
     * If a foreground task is already running, the returned handle reports a failure.
     *
     * To wait for foreground tasks to be available, use waitForForegroundTask().
     *
     * The function will set the state back to Idle once it sees ForegroundTaskState.Done.
     */
    private fun launchForegroundTask(
        title: String,
        failureTitle: String,
        iconRes: Int,
        task: suspend EuiccChannelManagerService.(Channel<Any>) -> Unit
    ): ForegroundTaskHandle {
        val taskId = taskIds.incrementAndGet()
        val backChannel = Channel<Any>(capacity = Channel.BUFFERED)
        if (!foregroundTaskState.compareAndSet(
                ForegroundTaskState.Idle,
                ForegroundTaskState.InProgress(0)
            )
        ) {
            backChannel.close()
            return ForegroundTaskHandle(
                taskId,
                flow { emit(ForegroundTaskState.Done(IllegalStateException("There are tasks currently running"))) },
                backChannel
            )
        }

        val stateFlow = MutableSharedFlow<ForegroundTaskState>(
            replay = 2,
            onBufferOverflow = BufferOverflow.DROP_OLDEST
        )
        foregroundTaskRecords[taskId] = ForegroundTaskRecord(stateFlow.asSharedFlow(), backChannel)
        foregroundTaskRecords.keys.sorted().dropLast(5).forEach(foregroundTaskRecords::remove)

        lifecycleScope.launch(Dispatchers.Main) {
            foregroundTaskState.applyCompletionTransform()
                .onEach { state ->
                    if (state !is ForegroundTaskState.InProgress || state.progress != 0) {
                        runCatching { updateForegroundNotification(title, iconRes) }
                    }
                    stateFlow.emit(state)
                }
                .onCompletion {
                    foregroundTaskState.value = ForegroundTaskState.Idle
                    backChannel.close()
                }
                .collect()
        }

        lifecycleScope.launch(Dispatchers.Main) {
            var acquiredWakeLock = false
            try {
                startForegroundService(Intent(this@EuiccChannelManagerService,
                    this@EuiccChannelManagerService::class.java).putExtra("taskId", taskId))
                withTimeout(30_000) { foregroundStarted.first { it == taskId } }
                updateForegroundNotification(title, iconRes)
                wakeLock.acquire(10 * 60 * 1000L)
                acquiredWakeLock = true

                withContext(Dispatchers.IO + NonCancellable) {
                    operationLock.withLock {
                        this@EuiccChannelManagerService.task(backChannel)
                    }
                }
                foregroundTaskState.value = ForegroundTaskState.Done(null)
            } catch (t: Throwable) {
                Log.e(TAG, "Foreground task failed: ${t.javaClass.simpleName}")
                foregroundTaskState.value = ForegroundTaskState.Done(t)
                if (isActive) {
                    runCatching { postForegroundTaskFailureNotification(failureTitle) }
                }
            } finally {
                if (acquiredWakeLock && wakeLock.isHeld) wakeLock.release()
                if (isActive && notificationJob?.isActive != true) stopSelf()
            }
        }

        return ForegroundTaskHandle(taskId, stateFlow.asSharedFlow().applyCompletionTransform(), backChannel)
    }

    private suspend fun runTrackedOperation(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId,
        op: suspend () -> Boolean
    ) = euiccChannelManager.beginTrackedOperation(slotId, portId, seId,
        notificationHandler = { sequence -> queueNotifications(NotificationKey(slotId, portId, seId), sequence) },
        op = op
    )

    private suspend fun queueNotifications(key: NotificationKey, afterSeq: Long) = withContext(Dispatchers.Main) {
        pendingNotifications[key]?.let {
            it.afterSeq = minOf(it.afterSeq, afterSeq)
            it.failures = 0
            it.generation++
        } ?: run { pendingNotifications[key] = NotificationRequest(afterSeq) }
        if (notificationJob?.isActive == true) return@withContext

        notificationJob = lifecycleScope.launch {
            try {
                while (pendingNotifications.isNotEmpty()) {
                    waitForForegroundTask()
                    delay(250)
                    val (card, request) = pendingNotifications.entries.first().let { it.key to it.value }
                    val generation = request.generation
                    try {
                        val result = withContext(Dispatchers.IO) {
                            operationLock.withLock {
                                if (foregroundTaskState.value != ForegroundTaskState.Idle) return@withLock null
                                euiccChannelManager.withEuiccChannel(card.slotId, card.portId, card.seId) { channel ->
                                    val notification = channel.lpa.notifications
                                        .filter { it.seqNumber > request.afterSeq }.minByOrNull { it.seqNumber }
                                    if (notification == null) return@withEuiccChannel -1L
                                    check(channel.lpa.handleNotification(notification.seqNumber)) { "Notification not accepted" }
                                    notification.seqNumber
                                }
                            }
                        } ?: continue
                        if (result == -1L) {
                            if (request.generation == generation) pendingNotifications.remove(card)
                        } else {
                            request.afterSeq = maxOf(request.afterSeq, result)
                            request.failures = 0
                        }
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        Log.w(TAG, "Notification delivery failed: ${e.javaClass.simpleName}")
                        if (++request.failures >= 3 && request.generation == generation) pendingNotifications.remove(card)
                        else delay(request.failures * 1_000L)
                    }
                }
            } finally {
                notificationJob = null
                if (isActive && foregroundTaskState.value == ForegroundTaskState.Idle) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        }
    }

    open suspend fun waitForForegroundTask() {
        foregroundTaskState.takeWhile { it != ForegroundTaskState.Idle }
            .collect()
    }

    open fun launchProfileDownloadTask(
        slotId: Int, portId: Int, seId: EuiccChannel.SecureElementId,
        input: ProfileDownloadInput,
    ): ForegroundTaskHandle =
        launchForegroundTask(
            getString(R.string.task_profile_download),
            getString(R.string.task_profile_download_failure),
            R.drawable.ic_task_sim_card_download
        ) { backChannel ->
            runTrackedOperation(slotId, portId, seId) {
                euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                    channel.lpa.downloadProfile(input) { state ->
                        val progress = state.downloadProgress
                        foregroundTaskState.value = ForegroundTaskState.InProgress(
                            progress,
                            state
                        )

                        if (state is ProfileDownloadState.ConfirmingDownload) {
                            // Try to receive a signal for confirmation while blocking this thread
                            // This of course assumes we're NOT on the main thread here. We aren't,
                            // because we don't run download on the main thread; see withEuiccChannel.
                            return@downloadProfile runBlocking {
                                try {
                                    // We can't wait indefinitely; just time out after 1 minute.
                                    withTimeout(60 * 1000) {
                                        backChannel.receive() as Boolean
                                    }
                                } catch (_: TimeoutCancellationException) {
                                    // Default to cancelling / aborting here if we didn't receive a confirmation signal
                                    false
                                }
                            }
                        }

                        true
                    }
                }

                preferenceRepository.notificationDownloadFlow.first()
            }
        }

    fun launchProfileRenameTask(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId,
        iccid: String,
        name: String
    ): ForegroundTaskHandle =
        launchForegroundTask(
            getString(R.string.task_profile_rename),
            getString(R.string.task_profile_rename_failure),
            R.drawable.ic_task_rename
        ) { _ ->
            euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                channel.lpa.setNickname(
                    iccid,
                    name
                )
            }
        }

    fun launchProfileDeleteTask(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId,
        iccid: String,
        allowActive: Boolean = false
    ): ForegroundTaskHandle =
        launchForegroundTask(
            getString(R.string.task_profile_delete),
            getString(R.string.task_profile_delete_failure),
            R.drawable.ic_task_delete
        ) { _ ->
            var warning: Exception? = null
            runTrackedOperation(slotId, portId, seId) {
                val active = euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                    channel.lpa.profiles.find { it.iccid == iccid }?.isEnabled == true
                }
                if (active) {
                    check(allowActive) { "Active profile deletion was not confirmed" }
                    check(slotId == EuiccChannelManager.USB_CHANNEL_ID ||
                        preferenceRepository.disableSafeguardFlow.first()) { "Active profile safeguard is enabled" }
                    warning = switchProfileState(slotId, portId, seId, iccid, false, 30_000)
                    check(warning !is SwitchingProfilesReconnectException) { "Card did not reconnect before deletion" }
                }
                euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                    check(channel.lpa.profiles.find { it.iccid == iccid }?.isEnabled != true) {
                        "Profile must be disabled before deletion"
                    }
                    check(channel.lpa.deleteProfile(iccid)) { "Could not delete profile" }
                }
                preferenceRepository.notificationDeleteFlow.first() ||
                    (active && preferenceRepository.notificationSwitchFlow.first())
            }
            warning?.let { throw it }
        }

    class SwitchingProfilesRefreshException : Exception()
    class SwitchingProfilesReconnectException : Exception()

    private suspend fun switchProfileState(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId,
        iccid: String,
        enable: Boolean,
        reconnectTimeoutMillis: Long
    ): Exception? {
        var warning: Exception? = null
        val (response, refreshed) = euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
            val refresh = preferenceRepository.refreshAfterSwitchFlow.first()
            val response = channel.lpa.switchProfile(iccid, enable, refresh)
            if (response || !refresh) response to refresh
            else channel.lpa.switchProfile(iccid, enable, refresh = false) to false
        }
        check(response) { "Could not switch profile" }
        if (!refreshed && slotId != EuiccChannelManager.USB_CHANNEL_ID) {
            warning = SwitchingProfilesRefreshException()
        } else if (reconnectTimeoutMillis > 0) {
            val initialDelay = if (slotId == EuiccChannelManager.USB_CHANNEL_ID) {
                reconnectTimeoutMillis / 10
            } else minOf(1_000L, reconnectTimeoutMillis / 10)
            delay(initialDelay)
            try {
                euiccChannelManager.waitForReconnect(slotId, portId, reconnectTimeoutMillis - initialDelay)
            } catch (_: TimeoutCancellationException) {
                warning = SwitchingProfilesReconnectException()
            }
        }
        if (warning !is SwitchingProfilesReconnectException) {
            euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                check(channel.lpa.profiles.find { it.iccid == iccid }?.isEnabled == enable) {
                    "Profile state did not change"
                }
            }
        }
        return warning
    }

    fun launchProfileSwitchTask(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId,
        iccid: String,
        enable: Boolean,
        reconnectTimeoutMillis: Long = 0
    ): ForegroundTaskHandle =
        launchForegroundTask(
            getString(R.string.task_profile_switch),
            getString(R.string.task_profile_switch_failure),
            R.drawable.ic_task_switch
        ) { _ ->
            var warning: Exception? = null
            runTrackedOperation(slotId, portId, seId) {
                warning = switchProfileState(slotId, portId, seId, iccid, enable, reconnectTimeoutMillis)
                preferenceRepository.notificationSwitchFlow.first()
            }
            warning?.let { throw it }
        }

    fun launchMemoryReset(
        slotId: Int,
        portId: Int,
        seId: EuiccChannel.SecureElementId
    ): ForegroundTaskHandle =
        launchForegroundTask(
            getString(R.string.task_euicc_memory_reset),
            getString(R.string.task_euicc_memory_reset_failure),
            R.drawable.ic_euicc_memory_reset
        ) { _ ->
            runTrackedOperation(slotId, portId, seId) {
                euiccChannelManager.withEuiccChannel(slotId, portId, seId) { channel ->
                    channel.lpa.euiccMemoryReset()
                }

                preferenceRepository.notificationDeleteFlow.first()
            }
        }
}
