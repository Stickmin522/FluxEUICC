package im.angry.openeuicc.ui

import android.content.Context
import android.content.res.ColorStateList
import android.view.Gravity
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.google.android.material.button.MaterialButton
import com.google.android.material.color.MaterialColors

object ModernActionSheet {
    data class Action(
        val title: String,
        val icon: Int = 0,
        val destructive: Boolean = false,
        val run: () -> Unit,
    )

    fun show(context: Context, title: String, actions: List<Action>) {
        val dialog = BottomSheetDialog(context)
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = (value * density + 0.5f).toInt()

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(12), dp(16), dp(24))
        }
        content.addView(TextView(context).apply {
            text = title
            textSize = 22f
            setTextColor(MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface))
            setPadding(dp(12), dp(8), dp(12), dp(16))
        })

        actions.forEach { action ->
            content.addView(MaterialButton(context).apply {
                text = action.title
                textSize = 16f
                gravity = Gravity.CENTER_VERTICAL or Gravity.START
                textAlignment = MaterialButton.TEXT_ALIGNMENT_VIEW_START
                minHeight = dp(56)
                isAllCaps = false
                iconPadding = dp(16)
                backgroundTintList = ColorStateList.valueOf(
                    MaterialColors.getColor(this, com.google.android.material.R.attr.colorSurfaceContainerLow)
                )
                val onSurface = MaterialColors.getColor(this, com.google.android.material.R.attr.colorOnSurface)
                setTextColor(onSurface)
                if (action.icon != 0) setIconResource(action.icon)
                iconTint = ColorStateList.valueOf(onSurface)
                if (action.destructive) {
                    val error = MaterialColors.getColor(this, android.R.attr.colorError)
                    setTextColor(error)
                    iconTint = ColorStateList.valueOf(error)
                }
                setOnClickListener {
                    dialog.dismiss()
                    action.run()
                }
            }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)))
        }
        dialog.setContentView(content)
        dialog.show()
    }
}
