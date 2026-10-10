package im.angry.openeuicc.flutter

import android.content.Context
import org.json.JSONArray
import java.security.MessageDigest

class ProfileOrderStore(context: Context) {
    private val preferences = context.getSharedPreferences("profile_order", Context.MODE_PRIVATE)

    @Synchronized
    fun reconcile(eid: String, iccids: List<String>): Map<String, Int> {
        val key = MessageDigest.getInstance("SHA-256").digest(eid.toByteArray())
            .joinToString("") { "%02x".format(it) }
        val saved = runCatching {
            val array = JSONArray(preferences.getString(key, "[]"))
            List(array.length()) { array.getString(it) }
        }.getOrDefault(emptyList())
        val present = iccids.toSet()
        val order = (saved.filter { it in present } + iccids.filter { it !in saved }).distinct()
        if (order != saved) preferences.edit().putString(key, JSONArray(order).toString()).apply()
        return order.withIndex().associate { it.value to it.index }
    }
}
