import 'package:flutter/material.dart';

import '../../../core/content/app_settings.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Görünüm: yazı boyutu ve OLED modu (bütün uygulamada, hemen).
class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key, required this.settings, this.padding = EdgeInsets.zero});

  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SettingsBody(
      title: 'Görünüm',
      padding: padding,
      children: [
        ChoiceSetting(
          title: 'Yazı boyutu',
          description: 'Bütün yazılar bu oranda büyür ya da küçülür.',
          values: TextSize.values,
          labelOf: (v) => v.label,
          selected: settings.textSize,
          onChanged: (v) => settings.textSize = v,
        ),
        SwitchSetting(
          title: 'OLED modu (saf siyah)',
          description: 'Arka planlar ve gezinti çubukları saf siyah olur; OLED ekranlarda pil tasarrufu sağlar.',
          value: settings.oled,
          onChanged: (v) => settings.oled = v,
        ),
      ],
    ),
  );
}
