import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/content/backup.dart';
import '../../../core/content/omdb.dart';
import '../../../core/content/song_history.dart';
import '../../../core/content/stored_api_key.dart';
import '../../../core/content/tmdb.dart';
import '../../../core/content/user_sources.dart';
import '../../../core/content/watch_history.dart';
import '../../../core/platform/storage_access.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../sources/file_browser_page.dart';
import '../widgets/api_key_setting.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Veriler: TMDB ve OMDb anahtarları; geçmişleri ve film/dizi bilgilerini temizle; bütün
/// ayarları ve listeleri dosyaya yedekle, dosyadan geri yükle.
class DataSettings extends StatelessWidget {
  const DataSettings({
    super.key,
    required this.sources,
    this.history,
    this.songs,
    this.tmdb,
    this.checkTmdbKey = Tmdb.checkKey,
    this.checkOmdbKey = Omdb.checkKey,
    this.backupFolder,
    this.fileRoots,
    this.padding = EdgeInsets.zero,
  });

  final UserSources sources;

  /// Bu profilin izleme geçmişi.
  final WatchHistory? history;
  final SongHistory? songs;
  final Tmdb? tmdb;

  /// Girilen anahtarların denetimi (testlerde sahte).
  final Future<ApiKeyCheck> Function(String key) checkTmdbKey;
  final Future<ApiKeyCheck> Function(String key) checkOmdbKey;

  /// Yedeğin yazılacağı klasör; null ise Backup.folder (testlerde geçici).
  final Future<Directory> Function()? backupFolder;

  /// Geri yüklemede dosya gezgininin kökleri (testlerde geçici klasör).
  final List<(String, String)>? fileRoots;
  final EdgeInsets padding;

  Future<void> _clearHistory(BuildContext context) async {
    if (!await confirmSetting(
      context,
      title: 'İzleme geçmişi silinsin mi?',
      text: 'Bu profilin "Son izlenen kanallar" listesi boşalır.',
    )) {
      return;
    }
    history!.clear();
    if (context.mounted) settingToast(context, 'İzleme geçmişi silindi.');
  }

  Future<void> _clearSongs(BuildContext context) async {
    if (!await confirmSetting(context, title: 'Son şarkılar silinsin mi?', text: 'Radyo › Son şarkılar boşalır.')) {
      return;
    }
    songs!.clear();
    if (context.mounted) settingToast(context, 'Son şarkılar silindi.');
  }

  Future<void> _clearTmdb(BuildContext context) async {
    await tmdb!.clearCache();
    await Omdb.shared?.clearCache();
    if (context.mounted) settingToast(context, 'Film ve dizi bilgileri silindi; açıldıkça yeniden alınır.');
  }

  Future<void> _backup(BuildContext context) async {
    // İzin yoksa yedek uygulamanın kendi klasörüne (gezginde "Uygulama
    // klasörü").
    final allowed = await StorageAccess.ensure();
    try {
      final dir = await (backupFolder ?? () => Backup.folder(allowed: allowed))();
      await dir.create(recursive: true);
      final file = File('${dir.path}/${Backup.fileName(DateTime.now())}');
      await file.writeAsString(await Backup.create(sources));
      if (context.mounted) settingToast(context, 'Yedek kaydedildi: ${file.path}');
    } on Object catch (e) {
      if (context.mounted) settingToast(context, 'Yedek kaydedilemedi ($e).');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final path = await Navigator.of(context).push(FileBrowserPage.route(roots: fileRoots));
    if (path == null || !context.mounted) return;
    if (!await confirmSetting(
      context,
      title: 'Yedek geri yüklensin mi?',
      text: 'Bu cihazdaki bütün ayarların, profillerin, favorilerin ve listelerin yerine yedektekiler geçer.',
      yes: 'Geri yükle',
    )) {
      return;
    }
    try {
      await Backup.restore(await File(path).readAsString(), sources);
    } on FormatException catch (e) {
      if (context.mounted) settingToast(context, e.message);
      return;
    } on Object catch (e) {
      if (context.mounted) settingToast(context, 'Geri yüklenemedi ($e).');
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: const Text('Yedek geri yüklendi'),
        content: const Text('Listeler hazır. Ayarların ve profillerin tamamı için uygulamayı kapatıp yeniden açın.'),
        actions: [PrimaryButton(label: 'Tamam', autofocus: true, onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsBody(
    title: 'Veriler',
    padding: padding,
    children: [
      if (history != null)
        ActionSetting(
          title: 'İzleme geçmişi',
          description: 'Anasayfa\'daki "Son izlenen kanallar" (bu profil).',
          label: 'Geçmişi temizle',
          icon: RedoxIcons.delete,
          onPressed: () => unawaited(_clearHistory(context)),
        ),
      if (songs != null)
        ActionSetting(
          title: 'Son şarkılar',
          description: 'Radyoda çalan son 15 şarkı.',
          label: 'Şarkıları temizle',
          icon: RedoxIcons.delete,
          onPressed: () => unawaited(_clearSongs(context)),
        ),
      if (tmdb != null)
        ActionSetting(
          title: 'Film ve dizi bilgileri (TMDB)',
          description: 'Afiş, özet ve puanlar cihazda saklanır; yanlış eşleşen bilgi varsa temizleyin.',
          label: 'Bilgileri temizle',
          icon: RedoxIcons.delete,
          onPressed: () => unawaited(_clearTmdb(context)),
        ),
      ActionSetting(
        title: 'Yedekle',
        description:
            'Ayarlar, profiller, favoriler, kilitler ve listeler tek dosyaya (İndirilenler) yazılır. Dosyada Xtream '
            'şifreleri de bulunur; paylaşmayın.',
        label: 'Yedek al',
        icon: RedoxIcons.backup,
        primary: true,
        onPressed: () => unawaited(_backup(context)),
      ),
      ActionSetting(
        title: 'Geri yükle',
        description: 'Daha önce alınan RedoX yedeğini seçin; bu cihazdakilerin yerine geçer.',
        label: 'Yedekten yükle',
        icon: RedoxIcons.restore,
        onPressed: () => unawaited(_restore(context)),
      ),
      ApiKeySetting(
        name: 'TMDB',
        description: 'Film ve dizi afişleri, özetleri ve puanları için. themoviedb.org hesabınızda Ayarlar › API.',
        store: Tmdb.key,
        check: checkTmdbKey,
      ),
      ApiKeySetting(
        name: 'OMDb',
        description:
            'IMDb puanı için (TMDB anahtarı da gerekir). Ücretsiz anahtarı omdbapi.com adresinden alın; günde 1000 '
            'istek sınırı vardır.',
        store: Omdb.key,
        check: checkOmdbKey,
        rejectedHint: ' Anahtarı e-postadaki bağlantıyla etkinleştirdiğinizden emin olun.',
      ),
    ],
  );
}
