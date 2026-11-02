import 'package:flutter/material.dart';

import '../../../core/content/app_settings.dart';
import '../widgets/setting_tiles.dart';

/// Ayarlar › Açılış. Sonraki açılışta geçerli olur.
class StartupSettings extends StatelessWidget {
  const StartupSettings({super.key, required this.settings, this.padding = EdgeInsets.zero});

  final AppSettings settings;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => SettingsBody(
      title: 'Açılış',
      padding: padding,
      children: [
        SwitchSetting(
          title: '"Kim izliyor?" her açılışta sorulsun',
          description: 'Kapalıysa son seçilen profil doğrudan açılır; profil başlıktaki profil düğmesiyle değişir.',
          value: settings.askProfile,
          onChanged: (v) => settings.askProfile = v,
        ),
        ChoiceSetting(
          title: 'Açılınca gelen sayfa',
          description: 'Son izlenen kanal kilitliyse Anasayfa açılır.',
          values: StartPage.values,
          labelOf: (v) => v.label,
          selected: settings.startPage,
          onChanged: (v) => settings.startPage = v,
        ),
      ],
    ),
  );
}
