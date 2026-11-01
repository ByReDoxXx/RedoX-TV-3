import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Metin türü: sistem klavyesinin düzeni buna göre.
enum TextKind {
  /// Ad: kelime başı büyük harf.
  text,

  /// Adres: URL klavyesi.
  url,

  /// Şifre: gizli.
  secret,

  /// MAC: büyük harf, öneri yok.
  mac,
}

/// Android TV'de metin girişi: cihazın kendi klavyesiyle (Chromecast'te
/// Gboard) yerel metin kutusu (kullanıcı isteği: "klavyeyi kendin yapma,
/// varsayılan klavyeyi kullan"). Flutter metin alanı açıkken Gboard
/// kumandanın yön tuşlarını alamıyor (flutter/flutter#154924; Chromecast'te
/// doğrulandı); yerel kutuda alıyor. Ayrıntı: MainActivity.showInput.
///
/// Döner: yazılan metin; vazgeçilirse null.
abstract final class SystemTextInput {
  static const _channel = MethodChannel('redox/metin');

  /// Testlerde yerel kutu yerine çağrılır.
  @visibleForTesting
  static Future<String?> Function(String title, String value, TextKind kind)? debugOverride;

  static Future<String?> ask({
    required String title,
    String value = '',
    TextKind kind = TextKind.text,
    int? maxLength,
  }) {
    if (debugOverride case final f?) return f(title, value, kind);
    return _channel.invokeMethod<String>('gir', {
      'baslik': title,
      'deger': value,
      'tur': kind.name,
      'enCok': ?maxLength,
    });
  }
}
