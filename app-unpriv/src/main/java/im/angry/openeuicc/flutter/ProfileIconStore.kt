package im.angry.openeuicc.flutter

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import kotlin.math.max
import kotlin.math.min

internal class ProfileIconStore(private val context: Context) {
    private val preferences = context.getSharedPreferences("profile_icons", Context.MODE_PRIVATE)

    private fun key(eid: String, iccid: String) = MessageDigest.getInstance("SHA-256")
        .digest("$eid|$iccid".toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    fun get(eid: String, iccid: String): String? = preferences.getString(key(eid, iccid), null)

    fun set(eid: String, iccid: String, encoded: String?) {
        val editor = preferences.edit()
        if (encoded == null) editor.remove(key(eid, iccid))
        else editor.putString(key(eid, iccid), encoded)
        check(editor.commit())
    }

    fun read(uri: Uri): String {
        val bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { decoder, info, _ ->
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            decoder.setTargetSampleSize(max(1, (max(info.size.width, info.size.height) + 511) / 512))
        }
        return try { encode(bitmap) } finally { bitmap.recycle() }
    }

    fun encode(bitmap: Bitmap): String {
        val side = min(bitmap.width, bitmap.height)
        val crop = Bitmap.createBitmap(bitmap, (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side)
        try {
            var size = min(side, 192)
            while (size >= 24) {
                val scaled = Bitmap.createScaledBitmap(crop, size, size, true)
                val bytes = try {
                    ByteArrayOutputStream().use { output ->
                        check(scaled.compress(if (bitmap.hasAlpha()) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG, 88, output))
                        output.toByteArray()
                    }
                } finally { if (scaled !== crop) scaled.recycle() }
                if (bytes.size <= 24_576) return Base64.encodeToString(bytes, Base64.NO_WRAP)
                size = size * 3 / 4
            }
            error("Image is too large")
        } finally { if (crop !== bitmap) crop.recycle() }
    }
}
