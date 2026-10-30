import 'package:flutter/material.dart';

import 'core/theme/redox_theme.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const Scaffold(body: Center(child: Text('RedoX TV 3.0'))),
    );
  }
}
