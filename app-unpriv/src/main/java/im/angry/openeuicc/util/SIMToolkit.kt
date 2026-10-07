package im.angry.openeuicc.util

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.annotation.ArrayRes
import im.angry.easyeuicc.R
import im.angry.openeuicc.core.EuiccChannelManager

class SIMToolkit(private val context: Context) {
    private val slots = buildMap {
        fun getIntents(@ArrayRes id: Int) = context.resources.getStringArray(id)
            .mapNotNull(ComponentName::unflattenFromString)
            .map(Intent::makeMainActivity)
        put(-1, getIntents(R.array.sim_toolkit_slot_selection))
        put(0, getIntents(R.array.sim_toolkit_slot_1))
        put(1, getIntents(R.array.sim_toolkit_slot_2))
    }

    val intents: Iterable<Intent?>
        get() = listOf(get(0), get(1))

    operator fun get(slotId: Int): Intent? {
        if (slotId < 0 || slotId == EuiccChannelManager.USB_CHANNEL_ID) return null
        val miui = Intent("miui.intent.action.StkMainHide")
            .setComponent(ComponentName("com.android.stk", "com.android.stk.StkMainHide"))
        val intents = (slots[slotId] ?: emptyList()) + slots[-1]!!
        val packageNames = intents.mapNotNull { it.component?.packageName ?: it.`package` }.toSet()
        val intent = getIntent(context.packageManager, listOf(miui) + intents)
            ?: getLaunchIntent(context.packageManager, packageNames)
            ?: return getDisabledPackageIntent(context.packageManager, packageNames)
        return Intent(intent).apply {
            putExtra("slot_id", slotId)
            putExtra("SLOT_ID", slotId)
            putExtra("android.telephony.extra.SLOT_INDEX", slotId)
        }
    }

    fun isSelection(intent: Intent) = intent.component?.className != "com.android.stk.StkMainHide" &&
        slots[-1]!!.any { it.component == intent.component }

    companion object {
        fun getDisabledPackageName(intent: Intent?): String? {
            if (intent?.action != Settings.ACTION_APPLICATION_DETAILS_SETTINGS) return null
            return intent.data!!.schemeSpecificPart
        }
    }
}


private fun getIntent(packageManager: PackageManager, intents: Iterable<Intent>) =
    intents.firstOrNull {
        runCatching { it.resolveActivityInfo(packageManager, 0)?.exported == true }.getOrDefault(false)
    }

private fun getLaunchIntent(packageManager: PackageManager, packageNames: Iterable<String>) =
    packageNames.firstNotNullOfOrNull(packageManager::getLaunchIntentForPackage)

private fun getDisabledPackageIntent(packageManager: PackageManager, packageNames: Iterable<String>): Intent? {
    val packageName = packageNames.firstOrNull(packageManager::isDisabledState) ?: return null
    val uri = Uri.fromParts("package", packageName, null)
    return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, uri)
}

private fun PackageManager.isDisabledState(packageName: String) =
    when (runCatching { getApplicationEnabledSetting(packageName) }.getOrNull()) {
        PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> true
        PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER -> true
        else -> false
    }
