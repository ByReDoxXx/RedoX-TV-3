import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Dosya gezgininin depolama erişimi ve kökleri. Android 11+ "Tüm dosyalara
/// erişim" (MANAGE_EXTERNAL_STORAGE; izin ekranını sistem açar, kullanıcı
/// anahtarı açar), daha eski Android'de okuma izni; masaüstünde izin yok.
abstract final class StorageAccess {
  /// Testlerde izin sorusu yerine.
  @visibleForTesting
  static Future<bool> Function()? debugOverride;

  /// Erişim var mı; yoksa ister. Android TV'de izin ekranı yoksa false.
  static Future<bool> ensure() async {
    if (debugOverride case final f?) return f();
    if (!Platform.isAndroid) return true;
    try {
      var all = await Permission.manageExternalStorage.status;
      if (all.isGranted) return true;
      if (!all.isRestricted) {
        all = await Permission.manageExternalStorage.request();
        if (all.isGranted) return true;
        if (!all.isRestricted) return false;
      }
      // Android 10 ve öncesi: "Tüm dosyalar" yok, okuma izni yeter.
      return (await Permission.storage.request()).isGranted;
    } on Object {
      return false;
    }
  }

  /// Uygulamanın kendi dış klasörü (`Android/data/<paket>/files`): izin
  /// istemez; izin yokken yedek buraya yazılır, gezgin burayı yine gösterir.
  static Future<String?> appFolder() async {
    if (!Platform.isAndroid) return null;
    try {
      return (await getExternalStorageDirectory())?.path;
    } on Object {
      return null;
    }
  }

  /// Gezilecek kökler (ad, yol): Android'de dahili depolama ve takılı USB/SD;
  /// Windows'ta sürücüler; Linux'ta ana klasör ve kök.
  ///
  /// Android'de takılı sürücüler sistemin depolama birimlerinden bulunur
  /// (her birimin uygulama klasörü `/storage/<birim>/Android/data/...`):
  /// `/storage` uygulamalara listelenmiyor (yalnız geçilebilir), Chromecast'te
  /// takılı SSD bu yüzden görünmüyordu ("SSD'yi görmüyor"; X-plore görüyor).
  static Future<List<(String, String)>> roots() async {
    if (Platform.isAndroid) {
      final volumes = <String>{
        ...await _volumes(),
        // Liste izni olan cihazlarda (eski Android) doğrudan da bakılır.
        for (final d in _list('/storage'))
          if (!const {'emulated', 'self'}.contains(_name(d))) d,
      };
      return [('Dahili depolama', '/storage/emulated/0'), for (final d in volumes) ('USB / SD kart (${_name(d)})', d)];
    }
    if (Platform.isWindows) {
      return [
        for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
          if (Directory('${String.fromCharCode(c)}:\\').existsSync())
            ('${String.fromCharCode(c)}: sürücüsü', '${String.fromCharCode(c)}:\\'),
      ];
    }
    return [if (Platform.environment['HOME'] case final home?) ('Ana klasör', home), ('Kök', '/')];
  }

  /// Takılı birimlerin kökleri: uygulamanın birim başına dış klasörlerinden
  /// (`/storage/6AE9-B46A/Android/data/<paket>/files` → `/storage/6AE9-B46A`);
  /// dahili depolama hariç.
  static Future<List<String>> _volumes() async {
    try {
      return [
        for (final d in await getExternalStorageDirectories() ?? const <Directory>[])
          if (d.path.indexOf('/Android/') case final i when i > 0)
            if (d.path.substring(0, i) case final root when !root.startsWith('/storage/emulated')) root,
      ];
    } on Object {
      return const [];
    }
  }

  static String _name(String path) => path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).lastOrNull ?? path;

  static List<String> _list(String path) {
    try {
      return [
        for (final e in Directory(path).listSync())
          if (e is Directory) e.path,
      ];
    } on FileSystemException {
      return const [];
    }
  }
}
