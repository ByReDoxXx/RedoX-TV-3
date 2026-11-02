import 'package:flutter/material.dart';

import '../../../core/content/app_settings.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Oynatıcı. Değişiklik sonraki kanal açılışında geçerli olur.
class PlayerSettings extends StatelessWidget {
  const PlayerSettings({super.key, required this.settings, this.padding = EdgeInsets.zero});

  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SettingsBody(
      title: 'Oynatıcı',
      padding: padding,
      children: [
        ChoiceSetting(
          title: 'Kalite sınırı',
          description:
              'Yayın birden çok kalite veriyorsa sınırın altındaki en yüksek kalite seçilir. 4K yayınlar '
              'takılıyorsa Full HD seçin.',
          values: QualityCap.values,
          labelOf: (v) => v.label,
          selected: settings.quality,
          onChanged: (v) => settings.quality = v,
        ),
        ChoiceSetting(
          title: 'Açılışta görüntü ölçeği',
          description: 'Oynatıcıdaki Seçenekler › Ölçek ile kanal başına değişir.',
          values: StartScale.values,
          labelOf: (v) => v.label,
          selected: settings.scale,
          onChanged: (v) => settings.scale = v,
        ),
        ChoiceSetting(
          title: 'Ön bellek',
          description: 'Yayın takılıyorsa artırın; kanal biraz daha geç açılır.',
          values: BufferSize.values,
          labelOf: (v) => v.label,
          selected: settings.buffer,
          onChanged: (v) => settings.buffer = v,
        ),
        SwitchSetting(
          title: 'Açılmayan akışta yedeğe geç',
          description: 'Kapalıysa kanal "açılamadı" der; sonraki akışı kendiniz seçersiniz.',
          value: settings.failover,
          onChanged: (v) => settings.failover = v,
        ),
        ChoiceSetting(
          title: 'Ses dili',
          description: 'Yayında birden çok ses varsa bu dil seçilir.',
          values: const [TrackLanguage.auto, TrackLanguage.turkish, TrackLanguage.english],
          labelOf: (v) => v.label,
          selected: settings.audio,
          onChanged: (v) => settings.audio = v,
        ),
        ChoiceSetting(
          title: 'Altyazı',
          description: 'Yayında altyazı varsa bu dil açılır.',
          values: TrackLanguage.values,
          labelOf: (v) => v.label,
          selected: settings.subtitles,
          onChanged: (v) => settings.subtitles = v,
        ),
      ],
    ),
  );
}
