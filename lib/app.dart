import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/layout/form_factor.dart';
import 'core/theme/redox_theme.dart';
import 'core/content/watch_history.dart';
import 'core/playback/frame_grabber.dart';
import 'core/playback/stream_probe.dart';
import 'features/shell/root_shell.dart';
import 'features/tv/tv_content.dart';

class RedoxApp extends StatelessWidget {
  const RedoxApp({super.key, required this.tv, this.history, this.frames, this.rank});

  /// Televizyon kanalları (gömülü M3U listesinden) ve yayın akışı; her
  /// dakika yenilenir (TvGuideController, main.dart).
  final ValueListenable<TvContent> tv;

  /// İzleme geçmişi (Anasayfa "Son izlenen kanallar").
  final WatchHistory? history;

  /// Kanalların yayından alınan kareleri (Anasayfa kartları).
  final FrameStore? frames;

  /// Akış sıralayıcı (StreamProbe.rank).
  final StreamRanker? rank;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedoX TV',
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.current),
      themeMode: ThemeMode.dark,
      // Açılış: Anasayfa. Anasayfa ve Televizyon gerçek kanal listesiyle;
      // Anasayfa'nın "Son izlenen kanallar" rafı izleme geçmişinden.
      home: ValueListenableBuilder(
        valueListenable: tv,
        builder: (context, tv, _) => RootShell(tv: tv, history: history, frames: frames, rank: rank),
      ),
    );
  }
}
