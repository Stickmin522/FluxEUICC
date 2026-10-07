package im.angry.openeuicc.util

import android.content.ComponentName
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import im.angry.openeuicc.core.EuiccChannelManager
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SIMToolkitTest {
    private val context get() = RuntimeEnvironment.getApplication()

    private fun install(vararg names: String) {
        val app = ApplicationInfo().apply { packageName = "com.android.stk"; enabled = true }
        val pkg = PackageInfo().apply {
            packageName = app.packageName
            applicationInfo = app
            activities = names.map { ActivityInfo().apply {
                name = "com.android.stk.$it"
                packageName = app.packageName
                applicationInfo = app
                enabled = true
                exported = true
            } }.toTypedArray()
        }
        shadowOf(context.packageManager).installPackage(pkg)
    }

    @Test
    fun miuiEntryReceivesTheSelectedZeroBasedSlotAndOverridesTheGenericEntry() {
        install("StkMainHide", "StkMain", "StkMain1", "StkMain2")
        val toolkit = SIMToolkit(context)
        for (slot in 0..1) {
            val intent = toolkit[slot]!!
            assertEquals(ComponentName("com.android.stk", "com.android.stk.StkMainHide"), intent.component)
            assertEquals(slot, intent.getIntExtra("slot_id", -1))
            assertEquals(slot, intent.getIntExtra("SLOT_ID", -1))
            assertFalse(toolkit.isSelection(intent))
        }
        assertEquals(0, toolkit[0]!!.getIntExtra("slot_id", -1))
    }

    @Test
    fun vendorSlotEntriesStayDistinctWithoutAMiuiEntry() {
        install("StkMain1", "StkMain2")
        assertEquals("com.android.stk.StkMain1", SIMToolkit(context)[0]!!.component!!.className)
        assertEquals("com.android.stk.StkMain2", SIMToolkit(context)[1]!!.component!!.className)
    }

    @Test
    fun genericSelectorIsRecognizedAfterCopyingTheIntent() {
        install("StkMain")
        val toolkit = SIMToolkit(context)
        assertTrue(toolkit.isSelection(toolkit[0]!!))
    }

    @Test
    fun absentToolkitAndUsbDoNotLaunchAnotherApp() {
        assertNull(SIMToolkit(context)[0])
        assertNull(SIMToolkit(context)[-1])
        assertNull(SIMToolkit(context)[EuiccChannelManager.USB_CHANNEL_ID])
    }
}
