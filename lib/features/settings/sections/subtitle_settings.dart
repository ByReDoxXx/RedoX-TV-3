import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/content/app_settings.dart';
import '../../../core/playback/subtitle_look.dart';
import '../../../core/theme/redox_shapes.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Altyazı (kullanıcı isteği: "Altyazı ayarları ekle"): dil,
/// boyut, yazı rengi, arka plan, konum ve kalın yazı; üstte seçimle değişen
/// örnek. Sonraki kanal açılışında geçerli olur.
class SubtitleSettings extends StatelessWidget {
  const SubtitleSettings({super.key, required this.settings, this.padding = EdgeInsets.zero});

  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SettingsBody(
      title: 'Altyazı',
      padding: padding,
      children: [
        _Preview(settings: settings),
        ChoiceSetting(
          title: 'Dil',
          description: 'Yayında altyazı varsa bu dil açılır; Kapalı ise hiç açılmaz.',
          values: TrackLanguage.values,
          labelOf: (v) => v.label,
          selected: settings.subtitles,
          onChanged: (v) => settings.subtitles = v,
        ),
        ChoiceSetting(
          title: 'Boyut',
          values: SubtitleSize.values,
          labelOf: (v) => v.label,
          selected: settings.subtitleSize,
          onChanged: (v) => settings.subtitleSize = v,
        ),
        ChoiceSetting(
          title: 'Yazı rengi',
          values: SubtitleColor.values,
          labelOf: (v) => v.label,
          selected: settings.subtitleColor,
          onChanged: (v) => settings.subtitleColor = v,
        ),
        ChoiceSetting(
          title: 'Arka plan',
          values: SubtitleBackground.values,
          labelOf: (v) => v.label,
          selected: settings.subtitleBackground,
          onChanged: (v) => settings.subtitleBackground = v,
        ),
        ChoiceSetting(
          title: 'Konum',
          description: 'Alt çubuk ya da logo altyazıyı örtüyorsa yukarı alın.',
          values: SubtitlePosition.values,
          labelOf: (v) => v.label,
          selected: settings.subtitlePosition,
          onChanged: (v) => settings.subtitlePosition = v,
        ),
        SwitchSetting(title: 'Kalın yazı', value: settings.subtitleBold, onChanged: (v) => settings.subtitleBold = v),
      ],
    ),
  );
}

/// 16:9 örnek kare: oynatıcıdaki ölçekle (1280x720 referans) altyazı.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RedoxRadius.md),
        child: LayoutBuilder(
          builder: (context, box) {
            // Oynatıcıyla aynı küçültme: alanın 1280x720'ye oranının karekökü.
            final scale = math.sqrt((box.maxWidth * box.maxHeight / (1280 * 720)).clamp(0.0, 1.0));
            final pad = SubtitleLook.padding(settings);
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B4A66), Color(0xFF8A6A5C), Color(0xFFD9B98A)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom * scale),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Bu bir altyazı örneğidir.\nAyarlar hemen burada görünür.',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(scale),
                    style: SubtitleLook.style(settings),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
