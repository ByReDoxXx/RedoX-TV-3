import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'features/home/home_content.dart';
import 'features/home/home_page.dart';

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
      home: const HomePage(content: HomeContent.preview),
    );
  }
}
