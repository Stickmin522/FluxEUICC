package im.angry.openeuicc.ui

import android.content.Intent
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.core.graphics.drawable.toBitmap
import im.angry.easyeuicc.R
import im.angry.openeuicc.util.*
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

class UnprivilegedMainActivity : MainActivity(), UnprivilegedEuiccContextMarker {
    private val stk by lazy {
        SIMToolkit(this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (runBlocking { !preferenceRepository.skipQuickCompatibilityFlow.first() }) {
            startActivity(Intent(this, QuickCompatibilityActivity::class.java))
        }
    }

    override fun appendAppMenuActions(actions: MutableList<ModernActionSheet.Action>) {
        actions += ModernActionSheet.Action(getString(R.string.compatibility_check)) {
                startActivity(Intent(this, QuickCompatibilityActivity::class.java))
        }
    }

    override fun buildShortcuts() = buildList {
        addAll(super.buildShortcuts())
        val context = this@UnprivilegedMainActivity
        fun addShortcut(intent: Intent, index: Int, label: String) {
            val id = "stk_slot_$index"
            val icon = packageManager.getActivityIcon(intent)
            val shortcut = ShortcutInfoCompat.Builder(context, id)
                .setShortLabel(label)
                .setIcon(IconCompat.createWithBitmap(icon.toBitmap()))
                .setIntent(intent)
                .build()
            add(shortcut)
        }
        for ((index, intent) in stk.intents.withIndex()) {
            if (stk.isSelection(intent ?: continue)) {
                val label = getString(R.string.shortcut_sim_toolkit)
                addShortcut(intent, index, label)
                break
            }
            val label = getString(R.string.shortcut_sim_toolkit_with_slot, index)
            addShortcut(intent, index, label)
        }
    }
}
