import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kilitli kanallar ve klasörler (kullanıcı isteği: "kanal ve klasöre şifre").
/// Şifre ebeveyn PIN'idir (ProfileStore); burada yalnız neyin kilitli olduğu
/// tutulur, cihazda saklanır. Kilit bütün profiller için geçerlidir.
///
/// Kilidi PIN ile açılan kayıt uygulama kapanana kadar açık kalır
/// ([unlock]): her açılışta yeniden sorulmaz.
class ContentLocks extends ChangeNotifier {
  ContentLocks([Set<String> locked = const {}, this._save]) : _locked = Set.of(locked);

  static const _key = 'kilitler';

  final Set<String> _locked;
  final Future<void> Function(Set<String>)? _save;
  final _unlocked = <String>{};

  static Future<ContentLocks> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ContentLocks(
      (prefs.getStringList(_key) ?? const <String>[]).toSet(),
      (set) => prefs.setStringList(_key, set.toList()),
    );
  }

  /// TV kanalı (numarası).
  static String channel(int number) => 'kanal:$number';

  /// Kaynaktaki klasör: kaynak kimliği ve kökten klasör adları (boş yol:
  /// bütün kaynak).
  static String folder(String sourceId, List<String> path) => 'klasor:$sourceId/${path.join('/')}';

  /// Kaynaktaki kayıt (yayın adresi).
  static String item(String url) => 'kayit:$url';

  /// Kayıt kendisi kilitli mi (üst klasörlerine bakmaz).
  bool isLocked(String key) => _locked.contains(key);

  /// Kilitli ve bu oturumda açılmamış.
  bool blocks(String key) => _locked.contains(key) && !_unlocked.contains(key);

  /// Klasörün kendisi ya da üstlerinden biri (kaynak dahil) kilitliyse,
  /// kilitli olanın anahtarı; değilse null.
  String? folderLock(String sourceId, List<String> path) {
    for (var n = 0; n <= path.length; n++) {
      final key = folder(sourceId, path.sublist(0, n));
      if (blocks(key)) return key;
    }
    return null;
  }

  void toggle(String key) {
    if (!_locked.remove(key)) _locked.add(key);
    _unlocked.remove(key);
    notifyListeners();
    unawaited(_save?.call(_locked));
  }

  /// Kaynak silindi: kaynağın, klasörlerinin ve [urls] kayıtlarının
  /// kilitleri kalkar.
  void forgetSource(String sourceId, Set<String> urls) {
    final prefix = folder(sourceId, const []);
    final before = _locked.length;
    _locked.removeWhere((k) => k.startsWith(prefix) || (k.startsWith('kayit:') && urls.contains(k.substring(6))));
    if (_locked.length == before) return;
    notifyListeners();
    unawaited(_save?.call(_locked));
  }

  /// PIN doğrulandı: oturum boyunca açık.
  void unlock(String key) {
    if (_unlocked.add(key)) notifyListeners();
  }
}
