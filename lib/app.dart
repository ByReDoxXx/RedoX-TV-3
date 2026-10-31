import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'features/style_guide/style_guide_page.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.current),
      themeMode: ThemeMode.dark,
      // Ekranlar tasarlanana kadar açılışta stil rehberi gösterilir.
      home: const StyleGuidePage(),
    );
  }
}
