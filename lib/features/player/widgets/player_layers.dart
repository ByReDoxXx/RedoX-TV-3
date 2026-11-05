import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/content/tmdb.dart';
import 'player_overlays.dart';
import 'vod_tv.dart';

/// Dokunmatikte Seçenekler: panelin dışına dokunmak kapatır.
class TouchOptionsLayer extends StatelessWidget {
  const TouchOptionsLayer({super.key, required this.panel, required this.onClose});

  final Widget panel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.7, maxWidth: math.min(360, size.width - 32)),
              child: panel,
            ),
          ),
        ),
      ],
    );
  }
}

/// TV: ◄► ile sarılırken altta kısa süre görünen sarma çubuğu.
class TvSeekToast extends StatelessWidget {
  const TvSeekToast({super.key, required this.seekBar});

  final Widget seekBar;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 24,
    right: 24,
    bottom: 24,
    child: DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: seekBar),
    ),
  );
}

/// TV film/dizi: duraklatınca solda afiş, ad ve özet; oynarken çubukla
/// birlikte yalnız ad (B tasarımı).
class TvVodInfoLayer extends StatelessWidget {
  const TvVodInfoLayer({
    super.key,
    required this.channel,
    required this.series,
    required this.tmdb,
    required this.playing,
  });

  final LiveChannel channel;
  final bool series;
  final Tmdb? tmdb;
  final bool playing;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0, 0.4, 0.7],
              colors: [Color(0xF00B0B20), Color(0xB30B0B20), Color(0x000B0B20)],
            ),
          ),
        ),
      ),
      Positioned(
        left: 36,
        top: 40,
        width: playing ? 420 : 480,
        child: VodInfo(channel: channel, series: series, tmdb: tmdb, full: !playing),
      ),
    ],
  );
}

/// TV'nin alt bölümü: sağ üstte saat; altta üst üste Seçenekler, ipuçları, bölüm
/// şeridi ve çubuk.
class TvPlayerPanel extends StatelessWidget {
  const TvPlayerPanel({super.key, required this.clock, required this.bar, this.options, this.hints, this.episodes});

  final String clock;
  final Widget bar;
  final Widget? options;
  final Widget? hints;
  final Widget? episodes;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(top: 16, right: 24, child: PlayerClock(clock)),
      Positioned(
        left: 24,
        right: 24,
        bottom: 16,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (options case final o?) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                    child: o,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hints case final h?) ...[
                Align(alignment: Alignment.centerLeft, child: h),
                const SizedBox(height: 10),
              ],
              if (episodes case final e?) ...[e, const SizedBox(height: 14)],
              bar,
            ],
          ),
        ),
      ),
    ],
  );
}
