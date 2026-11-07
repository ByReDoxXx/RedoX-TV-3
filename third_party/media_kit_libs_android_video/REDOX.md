# media_kit_libs_android_video (RedoX kopyası)

pub.dev'deki 1.3.8 sürümünün kopyası (MIT, LICENSE). Tek fark `android/build.gradle`:
`android/local.properties` dosyasında `redox.libmpv.dir` verilirse oradaki
`default-arm64-v8a.jar` ve `default-armeabi-v7a.jar` indirilen paketlerin yerine geçer.

Yamalı libmpv: libmpv-android-video-build v1.1.7 (mpv 78d43740f5, FFmpeg 6.0) ve
`patches/mpv/redox_render_at_time.patch`. `vo_mediacodec_embed` kareyi "hemen göster"
yerine gösterim zamanıyla (`av_mediacodec_render_buffer_at_time`) verir; Chromecast'te
karelerin ~%0,7'si ekrana gelmeden eziliyordu.

## Derleme

Linux'ta (Windows'ta WSL Ubuntu; kaynaklar Linux dosya sisteminde olmalı, NTFS sembolik bağlantıya izin vermez):

1. `https://github.com/media-kit/libmpv-android-video-build` deposunun `v1.1.7` etiketini alın.
2. `buildscripts` içinde `TRAVIS=1 bash include/download-sdk.sh` ve `bash include/download-deps.sh` çalıştırın.
3. Bu klasördeki `patches/mpv/redox_render_at_time.patch` dosyasını `buildscripts/patches/mpv/` altına kopyalayıp `bash patch.sh` çalıştırın.
4. `cp flavors/default.sh scripts/ffmpeg.sh`, ardından `./build.sh --arch armv7l mpv` ve `./build.sh --arch arm64 mpv`.
5. Çıkan `libmpv.so` dosyalarıyla paketin indirdiği `default-armeabi-v7a.jar` ve `default-arm64-v8a.jar` içindeki `libmpv.so` değiştirilir; jar'lar bir klasöre konur ve `android/local.properties` dosyasında `redox.libmpv.dir` o klasörü gösterir.

media_kit güncellenince yama yeniden uygulanıp derlenmeli.

## English

A local copy of `media_kit_libs_android_video` 1.3.8. If `android/local.properties` sets `redox.libmpv.dir`, the `default-<abi>.jar` files in that folder replace the downloaded ones. The patch makes mpv's `vo_mediacodec_embed` queue each frame with its presentation time (`av_mediacodec_render_buffer_at_time`) instead of releasing it immediately; on Chromecast about 0.7% of frames were being overwritten before reaching the screen. Build it with libmpv-android-video-build v1.1.7 using the steps above.
