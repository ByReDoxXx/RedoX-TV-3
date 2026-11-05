import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/brand/app_info.dart';
import '../../../core/content/backup.dart';
import '../../../core/content/diagnostics.dart';
import '../../../core/content/user_sources.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/platform/storage_access.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../tv/tv_guide_controller.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Hakkında: sürüm, kanal ve liste sayıları, kanal listesi ve
/// yayın akışının son güncellenmesi, "Şimdi güncelle"; tanılama günlüğü ve
/// hata raporu.
class AboutSettings extends StatefulWidget {
  const AboutSettings({
    super.key,
    required this.sources,
    this.guide,
    this.reportFolder,
    this.padding = EdgeInsets.zero,
  });

  final UserSources sources;

  /// Hata raporunun klasörü; null ise Backup.folder (testlerde geçici).
  final Future<Directory> Function()? reportFolder;
  final TvGuideController? guide;
  final EdgeInsets padding;

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  bool _busy = false;

  static String _when(DateTime? at) => at == null
      ? 'Bu açılışta güncellenmedi (uygulamadaki liste kullanılıyor)'
      : '${'${at.day}'.padLeft(2, '0')}.${'${at.month}'.padLeft(2, '0')}.${at.year} '
            '${'${at.hour}'.padLeft(2, '0')}:${'${at.minute}'.padLeft(2, '0')}';

  static String get _device {
    final kind = switch (FormFactor.current) {
      FormFactor.tv => 'TV',
      FormFactor.tablet => 'Tablet',
      FormFactor.phone => 'Telefon',
      FormFactor.desktop => 'Masaüstü',
    };
    final os = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
    return '$kind · $os';
  }

  String get _header => 'RedoX TV $appVersion · $_device · ${DateTime.now().toIso8601String()}';

  Future<void> _showLog() async {
    final t = Theme.of(context).textTheme;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: const Text('Tanılama günlüğü'),
        content: SizedBox(
          width: 640,
          height: 360,
          child: ListenableBuilder(
            listenable: Diagnostics.instance,
            builder: (context, _) {
              final lines = Diagnostics.instance.lines.reversed.toList();
              if (lines.isEmpty) return Text('Günlük boş.', style: t.bodyLarge);
              return ListView(
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(l, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurface)),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          GlassButton(label: 'Temizle', icon: RedoxIcons.delete, onPressed: Diagnostics.instance.clear),
          PrimaryButton(label: 'Kapat', autofocus: true, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Future<void> _saveReport() async {
    if (!await StorageAccess.ensure()) {
      if (mounted) settingToast(context, 'Rapor için "Tüm dosyalara erişim" izni gerekiyor.');
      return;
    }
    try {
      final dir = await (widget.reportFolder ?? Backup.folder)();
      await dir.create(recursive: true);
      final name = Backup.fileName(DateTime.now()).replaceFirst('yedek', 'hata-raporu').replaceFirst('.json', '.txt');
      final file = File('${dir.path}/$name');
      await file.writeAsString(Diagnostics.instance.report(header: _header));
      if (mounted) settingToast(context, 'Rapor kaydedildi: ${file.path}');
    } on Object catch (e) {
      if (mounted) settingToast(context, 'Rapor kaydedilemedi ($e).');
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await widget.guide!.refreshNow();
    } on Object {
      if (mounted) settingToast(context, 'Güncellenemedi; internet bağlantısını kontrol edin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    return ListenableBuilder(
      listenable: Listenable.merge([?guide, ?guide?.channelsUpdated, ?guide?.guideUpdated, widget.sources]),
      builder: (context, _) => SettingsBody(
        title: 'Hakkında',
        padding: widget.padding,
        children: [
          const _BrandMeaning(),
          const InfoRow(label: 'Uygulama', value: 'RedoX TV $appVersion'),
          InfoRow(label: 'Cihaz', value: _device),
          if (guide != null) ...[
            InfoRow(label: 'TV kanalları', value: '${guide.value.channels.length} kanal'),
            InfoRow(label: 'Kanal listesi', value: _when(guide.channelsUpdated.value)),
            InfoRow(label: 'Yayın akışı', value: _when(guide.guideUpdated.value)),
          ],
          InfoRow(
            label: 'Listelerim',
            value: '${widget.sources.items.length} liste · ${widget.sources.channelCount} kayıt',
          ),
          if (guide != null)
            ActionSetting(
              title: 'Kanal listesi ve yayın akışı',
              description: 'Kendiliğinden açılışta ve 6 saatte bir güncellenir.',
              label: _busy ? 'Güncelleniyor…' : 'Şimdi güncelle',
              icon: RedoxIcons.sync,
              onPressed: _busy ? null : () => unawaited(_refresh()),
            ),
          ListenableBuilder(
            listenable: Diagnostics.instance,
            builder: (context, _) => ActionSetting(
              title: 'Tanılama günlüğü (${Diagnostics.instance.lines.length} satır)',
              description: 'Bu açılıştaki hatalar ve açılmayan yayınlar. Adresler yalnız sunucu adıyla yazılır.',
              label: 'Günlüğü göster',
              icon: RedoxIcons.info,
              onPressed: () => unawaited(_showLog()),
            ),
          ),
          ActionSetting(
            title: 'Hata raporu',
            description:
                'Günlük ve cihaz bilgisi bir metin dosyasına (İndirilenler) yazılır; sorun bildirirken gönderin.',
            label: 'Rapor kaydet',
            icon: RedoxIcons.backup,
            onPressed: () => unawaited(_saveReport()),
          ),
          Text(
            "Bu sürüm eski RedoX TV'den ayrı bir uygulamadır; ayarları ve verileri paylaşılmaz.",
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Adın anlamı. Sayfanın başında: yazı odak almaz, kumandayla sayfa sonuna inilemeyebilir.
class _BrandMeaning extends StatelessWidget {
  const _BrandMeaning();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RedoX ne demek?',
          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Redoks, yanmayı da oluşturan kimyasal bir tepkimedir: yanma, redoks tepkimesinin bilinen bir örneğidir. '
          'Ad aynı zamanda Red + oX, yani kırmızı boğa anlamına gelir; logodaki alevli boğa da buradan gelir.',
          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
      ],
    );
  }
}
