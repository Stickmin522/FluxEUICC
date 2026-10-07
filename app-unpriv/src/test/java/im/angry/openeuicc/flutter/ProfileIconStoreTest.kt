package im.angry.openeuicc.flutter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Base64
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class ProfileIconStoreTest {
    @Test
    fun cropsAndBoundsTheThumbnailWithoutRecyclingTheOriginal() {
        val bitmap = Bitmap.createBitmap(800, 400, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.MAGENTA)
        val encoded = ProfileIconStore(RuntimeEnvironment.getApplication()).encode(bitmap)
        assertTrue(encoded.length <= 32768)
        val bytes = Base64.decode(encoded, Base64.DEFAULT)
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        assertEquals(192, decoded.width)
        assertEquals(192, decoded.height)
        assertFalse(bitmap.isRecycled)
        decoded.recycle()
        bitmap.recycle()
    }

    @Test
    fun persistsPerCardAndProfileAndRestoresOnlyTheSelectedIcon() {
        val context = RuntimeEnvironment.getApplication()
        val store = ProfileIconStore(context)
        store.set("card-a", "profile-a", "first")
        store.set("card-b", "profile-a", "second")
        store.set("card-a", "profile-b", "third")
        assertEquals("first", ProfileIconStore(context).get("card-a", "profile-a"))
        store.set("card-a", "profile-a", null)
        assertNull(store.get("card-a", "profile-a"))
        assertEquals("second", store.get("card-b", "profile-a"))
        assertEquals("third", store.get("card-a", "profile-b"))
    }
}
