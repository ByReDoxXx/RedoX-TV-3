import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/brand/app_info.dart';
import '../../../core/content/user_sources.dart';
import '../../../core/ui/redox_icon.dart';
import '../../tv/tv_guide_controller.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Hakkında: sürüm, kanal ve liste sayıları, kanal listesi ve
/// yayın akışının son güncellenmesi; "Şimdi güncelle".
class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key, required this.sources, this.guide, this.padding = EdgeInsets.zero});

  final UserSources sources;
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
          const InfoRow(label: 'Uygulama', value: 'RedoX TV $appVersion'),
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
        ],
      ),
    );
  }
}
