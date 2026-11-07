import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// TV: ekranı filmin kare hızına geçirir. 23,976 fps film 60 Hz ekranda kareleri
/// sırayla 3 ve 2 yenileme tutar; hızlar tam oturmadığı için düzen arada kayar
/// (Chromecast'te görülen takılma). Ekran aynı çözünürlükte filmin hızının tam
/// katı olan en düşük yenilemeye geçer (23,976 → 23,976 Hz, 25 → 50 Hz). Uygun
/// mod yoksa (Philips'in kendisi yalnız 60 Hz sunuyor) değişmez. Geçişte TV
/// ekranı 1-2 sn kararabilir.
class DisplayRate {
  DisplayRate._();

  /// Modu son isteyen oynatıcı; yalnız o kapanınca ekran eski moduna döner
  /// (takılan oynatıcının yerine yenisi açılırken ikisi bir arada olur).
  static Object? _owner;

  /// Geçiş sonrası kontrol aralığı ve en çok yeniden istek sayısı.
  static const _check = Duration(seconds: 3);
  static const _retries = 3;

  /// Seçilen mod; uygun mod yoksa ya da okunamazsa null. [onRetry]: ekran geri
  /// döndüğü için mod yeniden istendi (günlük için).
  ///
  /// Chromecast'te mod değişince TV (Philips) HDMI bağlantısını kısa süre
  /// kesiyor; bağlantı dönünce Chromecast modları yeni numaralarla yeniden
  /// tanıyıp kendi varsayılanına (60 Hz) dönüyor ve istenen numara geçersiz
  /// kalıyor. Bu yüzden geçişten sonra ekran birkaç kez kontrol edilir; geri
  /// dönmüşse mod yeni numarasıyla yeniden istenir.
  static Future<DisplayMode?> match(Object owner, double fps, {void Function(int attempt)? onRetry}) async {
    try {
      final mode = await _request(owner, fps);
      if (mode == null) return null;
      unawaited(_keep(owner, fps, onRetry));
      return mode;
    } on PlatformException {
      return null;
    }
  }

  static Future<DisplayMode?> _request(Object owner, double fps) async {
    final mode = pickRate(await FlutterDisplayMode.supported, await FlutterDisplayMode.active, fps);
    if (mode == null) return null;
    _owner = owner;
    await FlutterDisplayMode.setPreferredMode(mode);
    return mode;
  }

  static Future<void> _keep(Object owner, double fps, void Function(int attempt)? onRetry) async {
    var attempt = 0;
    for (var i = 0; i < 5 && attempt < _retries; i++) {
      await Future<void>.delayed(_check);
      if (!identical(_owner, owner)) return;
      try {
        final active = await FlutterDisplayMode.active;
        if (pickRate([active], active, fps) != null) continue;
        attempt++;
        if (await _request(owner, fps) == null) return;
        onRetry?.call(attempt);
      } on PlatformException {
        return;
      }
    }
  }

  /// [owner] modu son isteyen oynatıcıysa ekran kullanıcının moduna döner.
  static Future<void> release(Object owner) async {
    if (!identical(_owner, owner)) return;
    _owner = null;
    try {
      await FlutterDisplayMode.setPreferredMode(DisplayMode.auto);
    } on PlatformException {
      // Etkinlik yoksa (arka plan) sistem modu zaten bırakır.
    }
  }
}

/// [modes] içinden [active] ile aynı çözünürlükte, yenilemesi [fps]'nin tam katı
/// olan en düşük mod; yoksa null. Tolerans binde yarım (59,94 ile 60 ayrılır).
@visibleForTesting
DisplayMode? pickRate(List<DisplayMode> modes, DisplayMode active, double fps) {
  if (fps <= 1) return null;
  DisplayMode? best;
  var bestTimes = 0;
  for (final mode in modes) {
    if (mode.id == 0 || mode.width != active.width || mode.height != active.height) continue;
    final ratio = mode.refreshRate / fps;
    final times = ratio.round();
    if (times < 1 || (ratio - times).abs() / times >= 0.0005) continue;
    if (best == null || times < bestTimes) {
      best = mode;
      bestTimes = times;
    }
  }
  return best;
}
