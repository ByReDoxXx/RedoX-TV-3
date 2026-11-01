package com.redoxtv.redox_tv

import android.app.AlertDialog
import android.text.InputFilter
import android.text.InputType
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "redox/metin").setMethodCallHandler { call, result ->
            if (call.method == "gir") {
                showInput(
                    title = call.argument<String>("baslik") ?: "",
                    value = call.argument<String>("deger") ?: "",
                    kind = call.argument<String>("tur") ?: "text",
                    maxLength = call.argument<Int>("enCok") ?: 0,
                    result = result,
                )
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Yerel metin kutusu: Android TV'nin kendi klavyesi (Gboard) kumandayla
     * gezilebilir. Flutter metin alanı açıkken yön tuşları klavyeye ulaşmıyor
     * (flutter/flutter#154924; Chromecast'te doğrulandı), yerel EditText'te
     * ulaşıyor. Tamam/klavyedeki onay: yazılan metin; Vazgeç/Geri: null.
     */
    private fun showInput(title: String, value: String, kind: String, maxLength: Int, result: MethodChannel.Result) {
        val edit = EditText(this).apply {
            setText(value)
            setSelection(value.length)
            setSingleLine(true)
            inputType = when (kind) {
                "url" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                "secret" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                "mac" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS or
                    InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
                else -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS
            }
            imeOptions = EditorInfo.IME_ACTION_DONE
            if (maxLength > 0) filters = arrayOf(InputFilter.LengthFilter(maxLength))
        }
        val box = FrameLayout(this).apply {
            val pad = (24 * resources.displayMetrics.density).toInt()
            setPadding(pad, pad / 2, pad, 0)
            addView(edit)
        }
        var answered = false
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle(title)
            .setView(box)
            .setPositiveButton("Tamam") { _, _ ->
                answered = true
                result.success(edit.text.toString())
            }
            .setNegativeButton("Vazgeç", null)
            .setOnDismissListener { if (!answered) result.success(null) }
            .create()
        edit.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                answered = true
                result.success(edit.text.toString())
                dialog.dismiss()
                true
            } else {
                false
            }
        }
        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        dialog.show()
        edit.requestFocus()
    }
}
