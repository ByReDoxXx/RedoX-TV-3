import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/storage_access.dart';
import 'user_sources.dart';

/// Yedek dosyası (Ayarlar › Veriler): bütün ayarlar (profiller, favoriler,
/// geçmiş, kilitler, PIN'in özeti, uygulama ayarları) ve kullanıcının
/// listeleri tek JSON dosyasında. Geri yüklenince uygulama yeniden
/// başlatılmalıdır (her şey açılışta okunur).
///
/// Güvenlik: Xtream şifresi ve portal MAC'i liste dizinindedir, yedekte de
/// bulunur; dosya başkasıyla paylaşılmamalıdır.
abstract final class Backup {
  static const format = 'redox-yedek';
  static const version = 1;

  /// Yedeğin JSON metni.
  static Future<String> create(UserSources sources) async {
    final prefs = await SharedPreferences.getInstance();
    final values = <String, Object?>{
      for (final key in prefs.getKeys())
        if (prefs.get(key) case final v?) key: v is List ? [for (final e in v) '$e'] : v,
    };
    return jsonEncode({
      'bicim': format,
      'surum': version,
      'tarih': DateTime.now().toIso8601String(),
      'ayarlar': values,
      'kaynaklar': await sources.exportData(),
    });
  }

  /// Yedeği geri yükler; dosya RedoX yedeği değilse [FormatException].
  static Future<void> restore(String text, UserSources sources) async {
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Dosya okunamadı.');
    }
    if (data is! Map || data['bicim'] != format) throw const FormatException('Bu dosya bir RedoX yedeği değil.');
    // Yalnız listeleri içeren yedek (ayarlar yok): bu cihazın ayarları
    // kalır, yedekteki listeler eldekilere eklenir.
    final listsOnly = data['ayarlar'] == null;
    if (listsOnly) {
      if (data['kaynaklar'] case final Map<String, Object?> s) await sources.importData(s, merge: true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final MapEntry(:key, :value) in ((data['ayarlar'] as Map?) ?? const {}).cast<String, Object?>().entries) {
      switch (value) {
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final double v:
          await prefs.setDouble(key, v);
        case final String v:
          await prefs.setString(key, v);
        case final List<Object?> v:
          await prefs.setStringList(key, [for (final e in v) '$e']);
      }
    }
    if (data['kaynaklar'] case final Map<String, Object?> s) await sources.importData(s);
  }

  /// Yedeğin yazılacağı klasör: Android'de İndirilenler (Tüm dosyalara
  /// erişim gerekir; yoksa uygulamanın kendi klasörü), masaüstünde
  /// İndirilenler ya da belgeler.
  static Future<Directory> folder({bool allowed = true}) async {
    if (Platform.isAndroid) {
      if (!allowed) {
        final app = await StorageAccess.appFolder();
        return app == null ? getApplicationDocumentsDirectory() : Directory(app);
      }
      return Directory('/storage/emulated/0/Download');
    }
    return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  }

  /// Dosya adı: RedoX-yedek-2026-11-02.json.
  static String fileName(DateTime at) =>
      'RedoX-yedek-${at.year}-${'${at.month}'.padLeft(2, '0')}-${'${at.day}'.padLeft(2, '0')}.json';
}
