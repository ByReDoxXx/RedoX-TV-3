import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'features/home/home_content.dart';
import 'features/shell/root_shell.dart';
import 'features/tv/tv_content.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key, required this.tv});

  /// Televizyon kanalları (gömülü M3U listesinden, main.dart).
  final TvContent tv;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.current),
      themeMode: ThemeMode.dark,
      // Açılış: Anasayfa. Anasayfa veri katmanı yazılana kadar örnek içerikle;
      // Televizyon gerçek kanal listesiyle.
      home: RootShell(home: HomeContent.preview, tv: tv),
    );
  }
}
