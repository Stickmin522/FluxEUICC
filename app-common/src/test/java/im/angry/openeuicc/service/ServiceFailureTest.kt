package im.angry.openeuicc.service

import android.content.ComponentName
import android.content.Intent
import android.os.Looper
import im.angry.openeuicc.core.EuiccChannel
import im.angry.openeuicc.service.EuiccChannelManagerService.Companion.waitDone
import im.angry.openeuicc.testutil.*
import im.angry.openeuicc.util.preferenceRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import net.typeblog.lpac_jni.LocalProfileNotification
import net.typeblog.lpac_jni.LocalProfileInfo
import net.typeblog.lpac_jni.ProfileClass
import net.typeblog.lpac_jni.ProfileDownloadInput
import org.junit.Assert.*
import org.junit.Before
import org.junit.After
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(application = TestOpenEuiccApplication::class, sdk = [28])
class ServiceFailureTest {
    private val seId = EuiccChannel.SecureElementId.DEFAULT
    private lateinit var service: EuiccChannelManagerService
    private lateinit var lpa: MockLpa

    @Before
    fun setUp() {
        lpa = MockLpa()
        TestOpenEuiccApplication.mockEuiccChannelManager = MockEuiccChannelManager(MockEuiccChannel(1, 0, lpa))
        service = Robolectric.buildService(EuiccChannelManagerService::class.java).get()
        resetPreferences()
    }

    @After
    fun resetPreferences() = runBlocking {
        service.preferenceRepository.disableSafeguardFlow.updatePreference(false)
        service.preferenceRepository.refreshAfterSwitchFlow.updatePreference(true)
    }

    private fun startService() {
        shadowOf(Looper.getMainLooper()).idle()
        service.onStartCommand(shadowOf(RuntimeEnvironment.getApplication()).nextStartedService, 0, 1)
    }

    private suspend fun done(handle: EuiccChannelManagerService.ForegroundTaskHandle): Throwable? {
        val result = kotlinx.coroutines.coroutineScope {
            val result = async(Dispatchers.Default) { handle.stateFlow.waitDone() }
            awaitMainLooper { result.isCompleted }
            result.await()
        }
        return result
    }

    @Test
    fun deleteFailureIsReportedAndNextTaskCanRun() = runBlocking {
        lpa.deleteResult = false
        val failed = service.launchProfileDeleteTask(1, 0, seId, "test-profile")
        startService()
        assertTrue(done(failed) is IllegalStateException)
        lpa.deleteResult = true
        val next = service.launchProfileDeleteTask(1, 0, seId, "test-profile")
        startService()
        assertNull(done(next))
        assertNotEquals(failed.taskId, next.taskId)
        assertTrue(done(service.recoverForegroundTaskSubscriber(failed.taskId)!!) is IllegalStateException)
    }

    @Test
    fun serviceStartFailureCompletesTask() = runBlocking {
        val rejected = Robolectric.buildService(RejectingService::class.java).get()
        val handle = rejected.launchProfileDeleteTask(1, 0, seId, "test-profile")
        assertTrue(done(handle) is IllegalStateException)
        assertEquals(0, lpa.deleteCalls)
    }

    @Test
    fun startTimeoutCompletesTaskAndLateStartDoesNotStartNextTask() = runBlocking {
        val first = service.launchProfileDeleteTask(1, 0, seId, "test-profile")
        shadowOf(Looper.getMainLooper()).idle()
        val oldIntent = shadowOf(RuntimeEnvironment.getApplication()).nextStartedService
        shadowOf(Looper.getMainLooper()).idleFor(31, TimeUnit.SECONDS)
        assertTrue(done(first) is TimeoutCancellationException)

        val next = service.launchProfileDeleteTask(1, 0, seId, "test-profile")
        shadowOf(Looper.getMainLooper()).idle()
        service.onStartCommand(oldIntent, 0, 1)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(0, lpa.deleteCalls)
        service.onStartCommand(shadowOf(RuntimeEnvironment.getApplication()).nextStartedService, 0, 2)
        assertNull(done(next))
        assertEquals(1, lpa.deleteCalls)
    }

    @Test
    fun downloadCompletesBeforeNotificationDeliveryAndFailedDeliveryIsRetried() = runBlocking {
        lpa.downloadNotification = LocalProfileNotification(1L, LocalProfileNotification.Operation.Install,
            "smdp.example.com", "test-profile")
        lpa.notificationFailures = 1
        val handle = service.launchProfileDownloadTask(1, 0, seId,
            ProfileDownloadInput("smdp.example.com", "test-code", null, null))
        startService()
        awaitMainLooper { lpa.downloadStarted.isCompleted }
        handle.backChannel.send(true)
        assertNull(done(handle))
        assertTrue(lpa.handledNotifications.isEmpty())

        shadowOf(Looper.getMainLooper()).idleFor(300, TimeUnit.MILLISECONDS)
        awaitMainLooper { lpa.handledNotifications.size == 1 }
        shadowOf(Looper.getMainLooper()).idle()
        awaitMainLooper {
            shadowOf(Looper.getMainLooper()).idleFor(250, TimeUnit.MILLISECONDS)
            lpa.handledNotifications.size >= 2
        }
        assertEquals(listOf(1L, 1L), lpa.handledNotifications.toList())
        assertEquals(1, lpa.notifications.size)
    }

    private fun installProfile() {
        lpa.profiles = listOf(LocalProfileInfo("test-profile", LocalProfileInfo.State.Disabled,
            "Test", "", "Test", "", ProfileClass.Operational))
    }

    @Test
    fun switchChecksCardStateBeforeReportingSuccess() = runBlocking {
        installProfile()
        val handle = service.launchProfileSwitchTask(1, 0, seId, "test-profile", true)
        startService()
        assertNull(done(handle))
        assertEquals(LocalProfileInfo.State.Enabled, lpa.profiles.single().state)
    }

    @Test
    fun unchangedProfileIsNotReportedAsSuccess() = runBlocking {
        installProfile()
        lpa.switchUpdatesProfile = false
        val handle = service.launchProfileSwitchTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(handle) is IllegalStateException)
    }

    @Test
    fun refreshFailureKeepsSuccessfulCardChangeDistinct() = runBlocking {
        installProfile()
        lpa.refreshBusy = true
        val handle = service.launchProfileSwitchTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(handle) is EuiccChannelManagerService.SwitchingProfilesRefreshException)
        assertEquals(LocalProfileInfo.State.Enabled, lpa.profiles.single().state)
    }

    private suspend fun activeDeletionAllowed() {
        installProfile()
        lpa.enableProfile("test-profile", false)
        service.preferenceRepository.disableSafeguardFlow.updatePreference(true)
        service.preferenceRepository.refreshAfterSwitchFlow.updatePreference(false)
    }

    @Test
    fun confirmedActiveDeletionDisablesAndVerifiesBeforeDeleting() = runBlocking {
        activeDeletionAllowed()
        val handle = service.launchProfileDeleteTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(handle) is EuiccChannelManagerService.SwitchingProfilesRefreshException)
        assertEquals(listOf("disable:test-profile:false", "delete:test-profile"), lpa.profileOperations)
    }

    @Test
    fun failedDisableDoesNotDeleteTheActiveProfile() = runBlocking {
        activeDeletionAllowed()
        lpa.disableResult = false
        val handle = service.launchProfileDeleteTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(handle) is IllegalStateException)
        assertEquals(0, lpa.deleteCalls)
    }

    @Test
    fun unchangedActiveStateDoesNotProceedToDeletion() = runBlocking {
        activeDeletionAllowed()
        lpa.switchUpdatesProfile = false
        val handle = service.launchProfileDeleteTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(handle) is IllegalStateException)
        assertEquals(0, lpa.deleteCalls)
    }

    @Test
    fun activeDeletionRequiresBothConfirmationAndSafeguardPermission() = runBlocking {
        activeDeletionAllowed()
        val unconfirmed = service.launchProfileDeleteTask(1, 0, seId, "test-profile")
        startService()
        assertTrue(done(unconfirmed) is IllegalStateException)
        service.preferenceRepository.disableSafeguardFlow.updatePreference(false)
        val guarded = service.launchProfileDeleteTask(1, 0, seId, "test-profile", true)
        startService()
        assertTrue(done(guarded) is IllegalStateException)
        assertEquals(0, lpa.deleteCalls)
        assertTrue(lpa.profileOperations.isEmpty())
    }

    class RejectingService : EuiccChannelManagerService() {
        override fun startForegroundService(service: Intent): ComponentName? {
            throw IllegalStateException("Service start rejected")
        }
    }
}
