package im.angry.openeuicc.flutter

import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ProfileOrderStoreTest {
    @Test
    fun switchingAndReopeningPreserveOrderWhileNewProfilesAppend() {
        val context = RuntimeEnvironment.getApplication()
        val store = ProfileOrderStore(context)
        assertEquals(mapOf("a" to 0, "b" to 1), store.reconcile("card", listOf("a", "b")))
        assertEquals(mapOf("a" to 0, "b" to 1),
            ProfileOrderStore(context).reconcile("card", listOf("b", "a")))
        assertEquals(mapOf("a" to 0, "b" to 1, "c" to 2),
            store.reconcile("card", listOf("c", "b", "a")))
    }

    @Test
    fun deletedProfilesReaddedLaterGoLastAndCardsHaveIndependentOrders() {
        val store = ProfileOrderStore(RuntimeEnvironment.getApplication())
        store.reconcile("card-a", listOf("a", "b", "c"))
        store.reconcile("card-b", listOf("c", "b", "a"))
        assertEquals(mapOf("a" to 0, "c" to 1), store.reconcile("card-a", listOf("c", "a")))
        assertEquals(mapOf("a" to 0, "c" to 1, "b" to 2),
            store.reconcile("card-a", listOf("b", "c", "a")))
        assertEquals(mapOf("c" to 0, "b" to 1, "a" to 2),
            store.reconcile("card-b", listOf("a", "b", "c")))
    }
}
