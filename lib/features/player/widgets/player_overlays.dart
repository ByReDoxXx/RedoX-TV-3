import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/playback/engine/playback_engine.dart';
import '../../../core/playback/playback_session.dart';

// Oynatıcının görüntü üstü katmanları (PlayerPage).

/// Yükleniyor / açılamadı durumu (görüntünün üstünde ortada).
class PlayerStatus extends StatelessWidget {
  const PlayerStatus({super.key, required this.session});

  final PlaybackSession session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = session;
    final stream = s.streamCount > 0 ? ' · Akış ${s.streamIndex + 1}/${s.streamCount}' : '';
    if (s.status == PlaybackStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 40,
              child: CircularProgressIndicator(color: RedoxRoles.primaryContainer, strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text('Yükleniyor$stream', style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
          ],
        ),
      );
    }
    // Açılamadı: odak "Tekrar dene"de (yeni odak alanı, kendiliğinden odak).
    return Center(
      child: FocusScope(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RedoxRoles.surfaceContainer,
            borderRadius: BorderRadius.circular(RedoxRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${s.channel.name} açılamadı',
                textAlign: TextAlign.center,
                style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                s.streamCount == 0 ? 'Bu kanalın yayın adresi yok.' : 'Bütün akışlar denendi, yanıt gelmedi.',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryButton(label: 'Tekrar dene', icon: RedoxIcons.sync, autofocus: true, onPressed: s.retry),
                  GlassButton(label: 'Sonraki kanal', icon: RedoxIcons.next, onPressed: () => s.zap(1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saat (sağ üstte, çubukla birlikte görünür).
class PlayerClock extends StatelessWidget {
  const PlayerClock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(RedoxRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RedoxIcon(RedoxIcons.clock, color: RedoxRoles.tertiary, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface, fontFeatures: RedoxType.tabular),
        ),
      ],
    ),
  );
}

/// Girilen kanal numarası (sol üstte, büyük).
class PlayerDigits extends StatelessWidget {
  const PlayerDigits(this.digits, {super.key});

  final String digits;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      border: Border.all(color: RedoxRoles.tertiary, width: 2),
    ),
    child: Text(
      digits,
      style: Theme.of(context).textTheme.headlineMedium!
          .copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w800, fontFeatures: RedoxType.tabular),
    ),
  );
}

/// Kısa bildirim (üstte ortada), örn. "Önceki kanal yok".
class PlayerNotice extends StatelessWidget {
  const PlayerNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(RedoxRadius.full),
    ),
    child: Text(text, style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface)),
  );
}

/// Yayın bilgisi paneli (Seçenekler › Yayın bilgisi): çözünürlük, kodek,
/// çözücü, kare hızı, bit hızı, ön bellek ve atlanan kare; saniyede bir
/// motordan okunur. Bozuk akışları ayırt etmek için.
class PlayerStats extends StatefulWidget {
  const PlayerStats({super.key, required this.engine, required this.stream});

  final PlaybackEngine engine;

  /// Örn. "Akış 1/2".
  final String stream;

  /// Örn. 4200000 → "4,2 Mb/sn", 128000 → "128 kb/sn".
  static String bitrate(int? bps) => switch (bps) {
    null || <= 0 => '—',
    final b when b >= 1000000 => '${_decimal(b / 1000000)} Mb/sn',
    final b => '${(b / 1000).round()} kb/sn',
  };

  /// Tek basamaklı ondalık, virgülle: 8.25 → "8,3".
  static String _decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  State<PlayerStats> createState() => _PlayerStatsState();
}

class _PlayerStatsState extends State<PlayerStats> {
  StreamStats _stats = const StreamStats();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_read()));
  }

  Future<void> _read() async {
    final s = await widget.engine.stats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine.state.value;
    final s = _stats;
    final rows = [
      ('Görüntü', e.hasVideo ? '${e.width}×${e.height}' : '—'),
      ('Kodek', '${s.videoCodec ?? '—'} · ${s.audioCodec ?? '—'}'),
      ('Çözücü', s.decoder ?? '—'),
      ('Kare hızı', s.fps == null ? '—' : '${PlayerStats._decimal(s.fps!)} fps'),
      ('Bit hızı', '${PlayerStats.bitrate(s.videoBitrate)} · ${PlayerStats.bitrate(s.audioBitrate)}'),
      ('Ön bellek', s.cache == null ? '—' : '${PlayerStats._decimal(s.cache!.inMilliseconds / 1000)} sn'),
      ('Atlanan kare', '${s.droppedFrames ?? '—'}'),
      ('Akış', widget.stream),
    ];
    final label = RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant);
    final value = RedoxType.bodySm.copyWith(
      color: RedoxRoles.onSurface,
      fontWeight: FontWeight.w600,
      fontFeatures: RedoxType.tabular,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(RedoxRadius.md)),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          for (final (k, v) in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 2),
                  child: Text(k, style: label),
                ),
                Text(v, style: value),
              ],
            ),
        ],
      ),
    );
  }
}
