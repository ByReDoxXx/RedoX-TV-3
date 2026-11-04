import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının Ayarlar'dan girdiği servis anahtarı: cihazda saklanır, uygulamaya
/// gömülmez. [current] anahtarla kurulan istemcidir; anahtar yoksa null.
class StoredApiKey<T> {
  StoredApiKey(this.pref, this._build);

  /// Anahtarın cihazdaki adı. Yedeğe yazılmaz (Backup).
  final String pref;
  final T Function(String key) _build;

  final current = ValueNotifier<T?>(null);

  /// Cihazdaki anahtarı yükler (main.dart).
  Future<void> load() async {
    final key = (await SharedPreferences.getInstance()).getString(pref);
    current.value = key == null || key.isEmpty ? null : _build(key);
  }

  /// Anahtarı saklar ve hemen kullanır; null kaldırır.
  Future<void> set(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove(pref);
      current.value = null;
    } else {
      await prefs.setString(pref, key);
      current.value = _build(key);
    }
  }
}

/// Girilen anahtarın denetim sonucu.
enum ApiKeyCheck {
  valid,

  /// Servis anahtarı reddetti (HTTP 401).
  rejected,

  /// Ağ yok ya da servis yanıt vermedi; anahtar denenemedi.
  unreachable,
}
