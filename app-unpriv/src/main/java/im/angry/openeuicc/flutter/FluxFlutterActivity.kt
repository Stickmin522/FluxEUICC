package im.angry.openeuicc.flutter

import android.content.Intent
import android.os.Bundle
import android.widget.FrameLayout
import androidx.activity.enableEdgeToEdge
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.core.graphics.drawable.toBitmap
import im.angry.openeuicc.common.R
import im.angry.easyeuicc.R as AppR
import im.angry.openeuicc.ui.BaseEuiccAccessActivity
import im.angry.openeuicc.util.UnprivilegedEuiccContextMarker
import im.angry.openeuicc.util.SIMToolkit
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister

class FluxFlutterActivity : BaseEuiccAccessActivity(), UnprivilegedEuiccContextMarker {
    lateinit var bridge: EuiccFlutterBridge
        private set
    private val flutter: FluxFlutterFragment?
        get() = supportFragmentManager.findFragmentByTag("flutter") as? FluxFlutterFragment

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        bridge = EuiccFlutterBridge(this)
        super.onCreate(savedInstanceState)
        val container = FrameLayout(this).apply { id = 0xF10C }
        setContentView(container)
        if (savedInstanceState == null) {
            val fragment = FlutterFragment.NewEngineFragmentBuilder(FluxFlutterFragment::class.java)
                .shouldAutomaticallyHandleOnBackPressed(true)
                .build<FluxFlutterFragment>()
            supportFragmentManager.beginTransaction().add(container.id, fragment, "flutter").commit()
        }
    }

    override fun onInit() = Unit

    fun updateShortcuts() {
        val shortcuts = mutableListOf(
            ShortcutInfoCompat.Builder(this, "download")
                .setShortLabel(getString(R.string.profile_download))
                .setIcon(IconCompat.createWithResource(this, R.drawable.ic_task_sim_card_download))
                .setIntent(Intent(this, FluxFlutterActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("route", "download")
                }).build()
        )
        val toolkit = SIMToolkit(this)
        for ((index, intent) in toolkit.intents.withIndex()) {
            if (intent == null) continue
            val selection = toolkit.isSelection(intent)
            val label = if (selection) getString(AppR.string.shortcut_sim_toolkit)
                else getString(AppR.string.shortcut_sim_toolkit_with_slot, index)
            shortcuts += ShortcutInfoCompat.Builder(this, "stk_slot_$index")
                .setShortLabel(label)
                .setIcon(IconCompat.createWithBitmap(packageManager.getActivityIcon(intent).toBitmap()))
                .setIntent(intent).build()
            if (selection) break
        }
        ShortcutManagerCompat.setDynamicShortcuts(this, shortcuts.take(4))
    }

    override fun onPostResume() {
        super.onPostResume()
        flutter?.onPostResume()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        flutter?.onNewIntent(intent)
        bridge.deliverIntent(intent)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        flutter?.onUserLeaveHint()
    }

    @Deprecated("Activity result forwarding for Flutter plugins")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        flutter?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        flutter?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        if (::bridge.isInitialized) bridge.close()
        super.onDestroy()
    }
}

class FluxFlutterFragment : FlutterFragment() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegister.registerGeneratedPlugins(flutterEngine)
        (requireActivity() as FluxFlutterActivity).bridge.attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
