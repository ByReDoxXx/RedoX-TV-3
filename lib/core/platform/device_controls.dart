import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Oynatıcı jestleri için cihaz sesi ve pencere parlaklığı (0–1). Android'de
/// MainActivity'deki `redox/cihaz` kanalı (AudioManager, pencere
/// parlaklığı); kanalın olmadığı yerde (masaüstü, testler) değer null döner
/// ve ayar yok sayılır.
abstract final class DeviceControls {
  static const _channel = MethodChannel('redox/cihaz');

  /// Testlerde kanal yerine kullanılır: ad → değer.
  @visibleForTesting
  static Map<String, double?>? debugValues;

  static Future<double?> volume() => _get('sesAl', 'ses');

  static Future<void> setVolume(double v) => _set('sesVer', 'ses', v.clamp(0, 1).toDouble());

  static Future<double?> brightness() => _get('parlaklikAl', 'parlaklik');

  /// null: sistemin parlaklığına dön (oynatıcıdan çıkınca).
  static Future<void> setBrightness(double? v) => _set('parlaklikVer', 'parlaklik', v?.clamp(0, 1).toDouble());

  static Future<double?> _get(String method, String key) async {
    if (debugValues case final d?) return d[key];
    try {
      return await _channel.invokeMethod<double>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _set(String method, String key, double? v) async {
    if (debugValues case final d?) {
      d[key] = v;
      return;
    }
    try {
      await _channel.invokeMethod<void>(method, v);
    } on MissingPluginException {
      // Masaüstü: cihaz ayarı yok.
    } on PlatformException {
      // Ayar yapılamadı; jest yalnız göstergeyi oynatır.
    }
  }
}
