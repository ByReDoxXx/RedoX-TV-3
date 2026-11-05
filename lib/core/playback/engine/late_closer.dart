import 'dart:async';

import '../../content/diagnostics.dart';

/// Vaktinde kapanmayan oynatıcılar. mpv çekirdeği meşgulken (donanım çözücü
/// kapanırken) oynatıcı kapatılamaz; açık kalan oynatıcı çözücüyü ve belleği
/// tutar (Philips: film oynarken ikinci çözücü dakikalarca açık kaldı; ölçüldü).
abstract final class LateCloser {
  /// Şu an kapanmamış oynatıcı sayısı.
  static int get open => _open;
  static int _open = 0;

  static set open(int value) {
    final before = _open > 0;
    _open = value;
    if ((value > 0) != before) onLeftoverChanged?.call(value > 0);
  }

  /// Kapanmamış oynatıcı var/yok değişince. Android'de uygulama çıkarken süreç
  /// kapatılsın diye: böyle bir oynatıcı Dart tarafı kapandıktan sonra geri çağrı
  /// yaparsa uygulama düşüyor (`Callback invoked after it has been deleted`).
  static void Function(bool leftover)? onLeftoverChanged;

  /// Çekirdek yanıt verince ([ready]) oynatıcıyı kapatır ([close]). [wait]
  /// içinde yanıt gelmezse oynatıcı bırakılır: kapatma çağrısı takılı çekirdekte
  /// arayüzü dondurabilir. Kapandıysa true.
  static Future<bool> closeWhenReady({
    required Future<void> Function() ready,
    required Future<void> Function() close,
    Duration wait = const Duration(minutes: 2),
  }) async {
    open++;
    Diagnostics.instance.log('oynatıcı', 'oynatıcı vaktinde kapanmadı, bekleniyor ($open açık)');
    try {
      await ready().timeout(wait);
    } on TimeoutException {
      Diagnostics.instance.log('oynatıcı', 'oynatıcı kapanmadı, bırakıldı ($open açık)');
      return false;
    } on Object {
      // Okuma hatası takılma değildir: kapatmayı dene.
    }
    open--;
    try {
      await close();
    } on Object {
      // Zaten kapanmış olabilir.
    }
    Diagnostics.instance.log('oynatıcı', 'oynatıcı sonradan kapandı ($open açık)');
    return true;
  }
}
