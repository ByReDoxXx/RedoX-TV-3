import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'features/home/home_content.dart';
import 'features/player/stream_probe.dart';
import 'features/shell/root_shell.dart';
import 'features/tv/tv_content.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key, required this.tv, this.rank});

  /// Televizyon kanalları (gömülü M3U listesinden) ve yayın akışı; her
  /// dakika yenilenir (TvGuideController, main.dart).
  final ValueListenable<TvContent> tv;

  /// Akış sıralayıcı (StreamProbe.rank).
  final StreamRanker? rank;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.current),
      themeMode: ThemeMode.dark,
      // Açılış: Anasayfa. Anasayfa veri katmanı yazılana kadar örnek içerikle;
      // Televizyon gerçek kanal listesiyle.
      home: ValueListenableBuilder(
        valueListenable: tv,
        builder: (context, tv, _) => RootShell(home: HomeContent.preview, tv: tv, rank: rank),
      ),
    );
  }
}
