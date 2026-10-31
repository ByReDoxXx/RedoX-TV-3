import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'features/home/home_content.dart';
import 'features/shell/root_shell.dart';
import 'features/tv/tv_content.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.current),
      themeMode: ThemeMode.dark,
      // Açılış: Anasayfa. Veri katmanı yazılana kadar örnek içerikle.
      home: const RootShell(home: HomeContent.preview, tv: TvContent.preview),
    );
  }
}
