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

  /// Seçilen mod; uygun mod yoksa ya da okunamazsa null.
  static Future<DisplayMode?> match(Object owner, double fps) async {
    try {
      final mode = pickRate(await FlutterDisplayMode.supported, await FlutterDisplayMode.active, fps);
      if (mode == null) return null;
      _owner = owner;
      await FlutterDisplayMode.setPreferredMode(mode);
      return mode;
    } on PlatformException {
      return null;
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
