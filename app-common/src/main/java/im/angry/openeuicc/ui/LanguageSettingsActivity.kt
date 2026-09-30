package im.angry.openeuicc.ui

import android.app.LocaleManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.LocaleList
import android.view.Gravity
import android.view.MenuItem
import android.view.ViewGroup
import android.widget.LinearLayout
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.NestedScrollView
import com.google.android.material.radiobutton.MaterialRadioButton
import im.angry.openeuicc.common.R
import im.angry.openeuicc.util.activityToolbarInsetHandler
import im.angry.openeuicc.util.mainViewPaddingInsetHandler
import im.angry.openeuicc.util.setupRootViewSystemBarInsets
import java.util.Locale

object AppLanguages {
    val supported = listOf(
        "en-US" to "English",
        "zh-CN" to "简体中文",
        "zh-TW" to "繁體中文",
        "ja" to "日本語",
        "ko" to "한국어",
        "ar" to "العربية",
        "fr" to "Français",
        "de" to "Deutsch",
        "es" to "Español",
    )

    fun followSystemLabel(context: Context): String {
        val label = context.getString(R.string.pref_advanced_language_system_default)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return label
        val systemLocale = context.getSystemService(LocaleManager::class.java)
            .systemLocales.get(0) ?: return label
        val supportedLanguage = supported.any { (tag, _) ->
            Locale.forLanguageTag(tag).language == systemLocale.language
        }
        return if (supportedLanguage) label else "$label (English)"
    }
}

class LanguageSettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_language_settings)
        setSupportActionBar(findViewById(R.id.toolbar))
        supportActionBar!!.setDisplayHomeAsUpEnabled(true)
        supportActionBar!!.setTitle(R.string.pref_advanced_language)

        val scroll = findViewById<NestedScrollView>(R.id.language_scroll)
        setupRootViewSystemBarInsets(
            window.decorView.rootView,
            arrayOf(this::activityToolbarInsetHandler, mainViewPaddingInsetHandler(scroll)),
            consume = false,
        )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val localeManager = getSystemService(LocaleManager::class.java)
        val current = localeManager.applicationLocales.toLanguageTags()
        val options = findViewById<LinearLayout>(R.id.language_options)
        addOption(options, AppLanguages.followSystemLabel(this), current.isEmpty()) {
            localeManager.applicationLocales = LocaleList.getEmptyLocaleList()
            finish()
        }
        AppLanguages.supported.forEach { (tag, name) ->
            val selected = current == tag ||
                (current.isNotEmpty() && Locale.forLanguageTag(current) == Locale.forLanguageTag(tag))
            addOption(options, name, selected) {
                localeManager.applicationLocales = LocaleList.forLanguageTags(tag)
                finish()
            }
        }
    }

    private fun addOption(parent: LinearLayout, label: String, checked: Boolean, onClick: () -> Unit) {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density + 0.5f).toInt()
        val row = MaterialRadioButton(this).apply {
            text = label
            textSize = 17f
            isChecked = checked
            minHeight = dp(64)
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), dp(10), dp(18), dp(10))
            setBackgroundResource(R.drawable.bg_preference_flux_row)
            setOnClickListener { onClick() }
        }
        parent.addView(row, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { setMargins(dp(16), dp(4), dp(16), dp(4)) })
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        android.R.id.home -> {
            finish()
            true
        }
        else -> super.onOptionsItemSelected(item)
    }
}
