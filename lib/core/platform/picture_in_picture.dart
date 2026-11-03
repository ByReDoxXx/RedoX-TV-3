import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Resim içinde resim (telefon/tablet): oynatıcı açıkken Ana ekrana çıkınca
/// yayın küçük pencerede sürer. Android'de MainActivity'deki `redox/pip`
/// kanalı; kanalın olmadığı yerde (masaüstü, testler) etkisizdir.
abstract final class PictureInPicture {
  static const _channel = MethodChannel('redox/pip');

  /// Uygulama şu an küçük pencerede mi (oynatıcı denetimleri gizler).
  static final active = ValueNotifier(false);

  static bool _listening = false;

  /// Oynatıcı açılınca true, kapanınca false.
  static Future<void> setEnabled(bool enabled) async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'kip') active.value = call.arguments == true;
      });
    }
    try {
      await _channel.invokeMethod<void>('etkin', enabled);
    } on MissingPluginException {
      // Masaüstü, testler.
    } on PlatformException {
      // Cihaz desteklemiyor.
    }
    if (!enabled) active.value = false;
  }
}
