# media_kit_libs_android_video (RedoX kopyası)

pub.dev'deki 1.3.8 sürümünün kopyası (MIT, LICENSE). Tek fark `android/build.gradle`:
`android/local.properties` dosyasında `redox.libmpv.dir` verilirse oradaki
`default-arm64-v8a.jar` ve `default-armeabi-v7a.jar` indirilen paketlerin yerine geçer.

Yamalı libmpv: libmpv-android-video-build v1.1.7 (mpv 78d43740f5, FFmpeg 6.0) ve
`patches/mpv/redox_render_at_time.patch`. `vo_mediacodec_embed` kareyi "hemen göster"
yerine gösterim zamanıyla (`av_mediacodec_render_buffer_at_time`) verir; Chromecast'te
karelerin ~%0,7'si ekrana gelmeden eziliyordu.

Derleme: WSL Ubuntu, `~/libmpv-build` (D:'deki NTFS bağlantıya izin vermez), betik
`D:/Tools/libmpv-redox/hazirla_ve_derle.sh`. Çıktı `D:/Tools/libmpv-redox/out/`.
media_kit güncellenince yama yeniden uygulanıp derlenmeli.
