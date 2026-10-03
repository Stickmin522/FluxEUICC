package im.angry.openeuicc.ui.wizard

import android.content.ComponentName
import android.content.Intent
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.textfield.TextInputLayout
import im.angry.openeuicc.common.R
import im.angry.openeuicc.service.EuiccChannelManagerService
import im.angry.openeuicc.testutil.MockEuiccChannel
import im.angry.openeuicc.testutil.MockEuiccChannelManager
import im.angry.openeuicc.testutil.MockLpa
import im.angry.openeuicc.testutil.TestOpenEuiccApplication
import im.angry.openeuicc.testutil.awaitMainLooper
import kotlinx.coroutines.runBlocking
import net.typeblog.lpac_jni.LocalProfileAssistant
import net.typeblog.lpac_jni.ProfileDownloadInput
import net.typeblog.lpac_jni.ProfileDownloadState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * A Robolectric UI test that drives the REAL DownloadWizardActivity through the
 * whole wizard flow -- slot select -> method select -> details -> download
 * progress -- until the download completes.
 *
 * Only the dependencies *below* EuiccChannelManagerService are mocked (manager ->
 * channel -> LPA, see testutil.Mocks). The activity, every wizard fragment, the
 * in-process service binding and the entire foreground-task machinery are the
 * real production code, so this test protects the actual UI flow that a user
 * experiences, not just the launchProfileDownload() contract in isolation.
 *
 * The MockLpa simulates a download that reaches ProfileDownloadState.ConfirmingDownload
 * and blocks until the subscriber confirms through the task's back channel --
 * exactly what a real download does before finishing.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = TestOpenEuiccApplication::class)
class DownloadWizardFlowTest {

    private val input = ProfileDownloadInput(
        address = "smdp.example.com",
        matchingId = "matching-id",
        imei = "imei",
        confirmationCode = "conf-code"
    )

    private lateinit var activity: DownloadWizardActivity
    private lateinit var service: EuiccChannelManagerService
    private lateinit var channel: MockEuiccChannel
    private lateinit var manager: MockEuiccChannelManager

    @Before
    fun setUp() {
        channel = MockEuiccChannel(slotId = 1, portId = 2)
        manager = MockEuiccChannelManager(channel)
        TestOpenEuiccApplication.mockEuiccChannelManager = manager

        // Robolectric does not auto-create services on bindService(); register the
        // REAL EuiccChannelManagerService (with the mock manager below it) as the
        // binding target so that BaseEuiccAccessActivity connects to it in-process.
        service = Robolectric.buildService(EuiccChannelManagerService::class.java).get()
        val bindIntent = Intent(
            RuntimeEnvironment.getApplication(),
            EuiccChannelManagerService::class.java
        )
        shadowOf(RuntimeEnvironment.getApplication())
            .setComponentNameAndServiceForBindServiceForIntent(
                bindIntent,
                ComponentName(
                    RuntimeEnvironment.getApplication(),
                    EuiccChannelManagerService::class.java
                ),
                service.onBind(Intent())
            )

        val intent = DownloadWizardActivity.newIntent(
            RuntimeEnvironment.getApplication(),
            logicalSlotId = 0
        )
        val controller = Robolectric.buildActivity(DownloadWizardActivity::class.java, intent)
        // The activity does not declare a theme itself; it inherits the host
        // app's application-level theme (Theme.OpenEUICC), which Robolectric
        // does not merge in for a library module. AppCompatActivity requires an
        // AppCompat theme, so apply it before onCreate() runs.
        controller.get().setTheme(R.style.Theme_OpenEUICC)
        activity = controller.setup().get()
        idle()

        // Wait until the in-process service connection is up and onInit() has run.
        runBlocking {
            awaitMainLooper { activity.euiccChannelManagerLoaded.isCompleted }
        }
        idle()
    }

    private fun idle() {
        shadowOf(Looper.getMainLooper()).idle()
    }

    private fun currentFragment(): DownloadWizardActivity.DownloadWizardStepFragment? =
        activity.supportFragmentManager
            .findFragmentById(R.id.step_fragment_container)
            as? DownloadWizardActivity.DownloadWizardStepFragment

    /**
     * RecyclerView children are only laid out when the Robolectric main looper
     * runs the view traversal; if that hasn't happened yet, force a layout so
     * that findViewHolderForAdapterPosition() works.
     */
    private fun RecyclerView.ensureLaidOut() {
        idle()
        if (childCount == 0) {
            measure(
                View.MeasureSpec.makeMeasureSpec(1080, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(1920, View.MeasureSpec.EXACTLY)
            )
            layout(0, 0, 1080, 1920)
            idle()
        }
    }

    private fun clickListItem(recyclerView: RecyclerView, position: Int) {
        recyclerView.ensureLaidOut()
        val holder = recyclerView.findViewHolderForAdapterPosition(position)
        assertNotNull("list item $position should be visible", holder)
        holder!!.itemView.performClick()
        idle()
    }

    private fun clickNext() {
        activity.findViewById<Button>(R.id.download_wizard_next).performClick()
        idle()
    }

    /**
     * Drive the wizard through slot select -> method select -> details form ->
     * download progress, and kick the service's foreground task machinery by
     * simulating the start command (Robolectric does not deliver
     * startForegroundService() on its own).
     */
    private suspend fun startDownload(deliverStart: Boolean = true) {
        // ---- Slot select: the mock manager exposes exactly one eUICC ----
        val slotList = activity.findViewById<RecyclerView>(R.id.download_slot_list)
        awaitMainLooper { (slotList.adapter?.itemCount ?: 0) > 0 }
        assertEquals(1, slotList.adapter?.itemCount)
        clickListItem(slotList, 0)

        // ---- Next -> method select ----
        clickNext()
        assertTrue(currentFragment() is DownloadWizardMethodSelectFragment)

        // ---- Pick the manual entry -> details form ----
        val methodList = activity.findViewById<RecyclerView>(R.id.download_method_list)
        awaitMainLooper { (methodList.adapter?.itemCount ?: 0) == 4 }
        clickListItem(methodList, 3) // download_wizard_method_manual
        assertTrue(currentFragment() is DownloadWizardDetailsFragment)

        // ---- Fill the form exactly as the user would ----
        val fields = mapOf(
            R.id.profile_download_server to input.address,
            R.id.profile_download_code to input.matchingId!!,
            R.id.profile_download_confirmation_code to input.confirmationCode!!,
            R.id.profile_download_imei to input.imei!!
        )
        fields.forEach { (id, text) ->
            activity.findViewById<TextInputLayout>(id).editText!!.setText(text)
        }
        idle()

        // ---- Next -> download progress; the download launches via the REAL service ----
        clickNext()
        assertTrue(currentFragment() is DownloadWizardProgressFragment)

        var startIntent: Intent? = null
        awaitMainLooper {
            shadowOf(RuntimeEnvironment.getApplication()).nextStartedService?.let {
                if (it.hasExtra("taskId")) startIntent = it
            }
            startIntent != null
        }
        if (deliverStart) service.onStartCommand(startIntent, 0, 1)
        idle()
    }

    private fun progressItemHolder(position: Int): RecyclerView.ViewHolder {
        val progressList = activity.findViewById<RecyclerView>(R.id.download_progress_list)
        progressList.ensureLaidOut()
        val holder = progressList.findViewHolderForAdapterPosition(position)
        assertNotNull("progress item $position should be visible", holder)
        return holder!!
    }

    /** Asserts that the given progress step currently shows a checkmark and no error text. */
    private fun assertProgressItemDone(position: Int) {
        val holder = progressItemHolder(position)
        val icon = holder.itemView.findViewById<ImageView>(R.id.download_progress_icon)
        val errorTitle = holder.itemView.findViewById<TextView>(R.id.download_progress_item_error_title)
        assertEquals("step $position should show a checkmark", View.VISIBLE, icon.visibility)
        assertEquals("step $position should not show an error", View.GONE, errorTitle.visibility)
    }

    /** Asserts that the given progress step currently shows the indeterminate spinner. */
    private fun assertProgressItemInProgress(position: Int) {
        val holder = progressItemHolder(position)
        val progressBar =
            holder.itemView.findViewById<ProgressBar>(R.id.download_progress_icon_progress)
        assertEquals("step $position should show the progress spinner", View.VISIBLE, progressBar.visibility)
    }

    /** Asserts that the given progress step currently shows the error state. */
    private fun assertProgressItemError(position: Int) {
        val holder = progressItemHolder(position)
        val errorTitle = holder.itemView.findViewById<TextView>(R.id.download_progress_item_error_title)
        assertEquals("step $position should show the error message", View.VISIBLE, errorTitle.visibility)
    }

    @Test
    fun startupTimeoutIsShownAsDownloadFailure() = runBlocking {
        startDownload(deliverStart = false)
        shadowOf(Looper.getMainLooper()).idleFor(31, java.util.concurrent.TimeUnit.SECONDS)
        awaitMainLooper { currentFragment()?.hasNext == true }
        assertProgressItemError(0)
        clickNext()
        assertTrue(currentFragment() is DownloadWizardDiagnosticsFragment)
    }

    @Test
    fun `wizard runs the full flow through the real service to a completed download`() = runBlocking {
        val lpa = channel.lpa as MockLpa

        startDownload()

        // ---- The download must complete and the UI must reflect it ----
        awaitMainLooper { lpa.downloadReturned.isCompleted }
        awaitMainLooper { currentFragment()?.hasNext == true }

        // The LPA received the exact input the UI passed, and the metadata
        // confirmation was auto-approved through the back channel.
        assertEquals(input, lpa.downloadInput)
        assertEquals(true, lpa.awaitDownloadResult())

        // The service resolved the physical slot/port through the manager and
        // launched the download with them.
        assertEquals(1 to 2, manager.physicalChannelRequests.first())

        // UI: every step the download reached shows a checkmark; nothing is stuck
        // in progress; the wizard offers to continue (i.e. no error).
        for (i in 0..2) {
            assertProgressItemDone(i)
        }
        // hasNext is true and no error -> the Next button must be visible so the
        // user can leave the (successful) download screen.
        assertEquals(
            View.VISIBLE,
            activity.findViewById<Button>(R.id.download_wizard_next).visibility
        )

        // Clicking Next after a successful download must finish the wizard
        // (createNextFragment() returns null when there is no error).
        clickNext()
        assertTrue("wizard should finish after a successful download", activity.isFinishing)
    }

    @Test
    fun `wizard streams intermediate progress while the download is still running`() = runBlocking {
        val lpa = channel.lpa as MockLpa
        // Simulate a real download that walks through Preparing, Connecting and
        // Authenticating before asking for metadata confirmation, and park it at
        // Authenticating so we can inspect the UI mid-download.
        lpa.preConfirmationStates = listOf(
            ProfileDownloadState.Preparing(),
            ProfileDownloadState.Connecting(),
            ProfileDownloadState.Authenticating(),
        )
        lpa.holdAt = ProfileDownloadState.Authenticating()

        startDownload()

        // Wait until the download has actually reached (and is parked at) the
        // authentication step.
        awaitMainLooper { lpa.isStateReached(ProfileDownloadState.Authenticating()) }

        // The UI must have streamed the progress live: the earlier steps already
        // show checkmarks and the current step shows the spinner -- it must NOT
        // jump straight from "nothing" to "done" at the end.
        assertProgressItemDone(0)
        assertProgressItemDone(1)
        assertProgressItemInProgress(2)

        // Let the download continue; it must complete normally afterwards.
        lpa.releaseHold()
        awaitMainLooper { lpa.downloadReturned.isCompleted }
        awaitMainLooper { currentFragment()?.hasNext == true }
        assertEquals(true, lpa.awaitDownloadResult())
        // The steps reached before the confirmation are all done; the download
        // finishes without leaving anything stuck in progress.
        for (i in 0..2) {
            assertProgressItemDone(i)
        }
    }

    @Test
    fun `wizard shows the reached steps and an error when the download fails before confirmation`() = runBlocking {
        val lpa = channel.lpa as MockLpa
        // The SM-DP+ rejects the device during authentication (step 3), i.e.
        // before any metadata confirmation happens -- this is the failure mode
        // that used to leave the progress UI stuck with no checkmarks at all.
        lpa.preConfirmationStates = listOf(
            ProfileDownloadState.Preparing(),
            ProfileDownloadState.Connecting(),
            ProfileDownloadState.Authenticating(),
        )
        lpa.failAfter = ProfileDownloadState.Authenticating()
        lpa.failure = LocalProfileAssistant.ProfileDownloadException(
            lpaErrorReason = "ES10B_ERROR_REASON_UNSUPPORTED_CRT_VALUES",
            lastHttpResponse = null,
            lastHttpException = null,
            lastApduResponse = null,
            lastApduException = null,
        )

        startDownload()

        // The download must fail and the wizard must then offer the diagnostics step.
        awaitMainLooper { currentFragment()?.hasNext == true }

        // The steps reached before the failure must be marked done...
        assertProgressItemDone(0)
        assertProgressItemDone(1)
        // ...and the failing step must show the error.
        assertProgressItemError(2)

        // The error must have been recorded so the diagnostics step can show it:
        // Next must lead to the diagnostics fragment (only created when an error
        // is present).
        clickNext()
        assertTrue(
            "next must lead to the diagnostics step after a failed download",
            currentFragment() is DownloadWizardDiagnosticsFragment
        )
    }
}
