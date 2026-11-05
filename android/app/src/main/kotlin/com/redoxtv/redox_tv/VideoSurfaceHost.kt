package com.redoxtv.redox_tv

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.ViewGroup
import android.widget.FrameLayout
import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * TV: film Flutter'ın çizim yüzeyine değil, onun arkasındaki ayrı bir SurfaceView'a
 * çizilir (Flutter yüzeyi saydam, arayüz üstte kalır). Doku yolunda film arayüzle
 * aynı 1080p katmandaydı (Philips); TV'nin video işlemesi ona uygulanmıyor olabilir.
 *
 * Dart kanalı `redox/video-yuzey`: "ac" (id), "konum" (id, x, y, g, y2), "kapat" (id,
 * tut). Olaylar: "hazir" (id, wid), "gitti" (id). `wid`, mpv'nin beklediği Surface
 * JNI başvurusudur; media_kit de aynısını verir.
 */
class VideoSurfaceHost(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "redox/video-yuzey")
    private val entries = HashMap<Int, Entry>()
    private val handler = Handler(Looper.getMainLooper())

    private inner class Entry(val id: Int) : SurfaceHolder.Callback {
        val view = SurfaceView(activity).apply {
            isFocusable = false
            isClickable = false
        }
        var ref = 0L

        /** Takılı oynatıcı bu yüzeyi tutuyor: başvuru silinmez. */
        var keep = false

        override fun surfaceCreated(holder: SurfaceHolder) {
            ref = MediaKitAndroidHelper.newGlobalObjectRef(holder.surface)
            channel.invokeMethod("hazir", mapOf("id" to id, "wid" to ref))
        }

        override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

        override fun surfaceDestroyed(holder: SurfaceHolder) {
            channel.invokeMethod("gitti", mapOf("id" to id))
            val old = ref
            ref = 0L
            // mpv yüzeyi bırakana dek başvuru yaşasın (media_kit de 5 sn bekliyor).
            if (old != 0L) {
                handler.postDelayed({ if (!keep) MediaKitAndroidHelper.deleteGlobalObjectRef(old) }, 5000)
            }
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            val id = call.argument<Int>("id") ?: 0
            when (call.method) {
                "ac" -> {
                    val entry = Entry(id)
                    entries[id] = entry
                    entry.view.holder.addCallback(entry)
                    val content = activity.findViewById<ViewGroup>(android.R.id.content)
                    content.addView(
                        entry.view,
                        0,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT,
                        ),
                    )
                    result.success(null)
                }
                "konum" -> {
                    entries[id]?.view?.let { view ->
                        view.layoutParams = FrameLayout.LayoutParams(
                            call.argument<Int>("genislik") ?: 0,
                            call.argument<Int>("yukseklik") ?: 0,
                        ).apply {
                            leftMargin = call.argument<Int>("sol") ?: 0
                            topMargin = call.argument<Int>("ust") ?: 0
                        }
                    }
                    result.success(null)
                }
                "kapat" -> {
                    entries.remove(id)?.let { entry ->
                        entry.keep = call.argument<Boolean>("tut") ?: false
                        (entry.view.parent as? ViewGroup)?.removeView(entry.view)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
