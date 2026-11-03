import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/content/watch_progress.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';
import 'continue_card.dart';

/// Kişisel pano (anasayfa B tasarımı): en son izlenen film/bölüm büyük kart,
/// yanında sonraki iki kayıt küçük kart. TV/tablette yan yana (sabit
/// yükseklik), telefonda büyük kart üstte, küçükler altta yan yana.
/// Bitmiş dizi bölümünde sıradaki bölüm önerilir ("SIRADAKİ").
class ResumeBoard extends StatelessWidget {
  const ResumeBoard({super.key, required this.entries, this.tmdb, this.onResume, this.previewFocus = false});

  /// Gösterilecek kayıtlar (en yeni önde); ilk üçü kullanılır.
  final List<ProgressEntry> entries;
  final Tmdb? tmdb;
  final ValueChanged<ProgressEntry>? onResume;

  /// Önizleme: büyük kartı odakta çiz.
  final bool previewFocus;

  /// Panodaki en çok kart.
  static const size = 3;

  /// TV/tablette panonun yüksekliği (540 dp tuvalde altındaki şerit görünsün).
  static const height = 232.0;

  @override
  Widget build(BuildContext context) {
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    final gap = phone ? 12.0 : 16.0;
    final first = entries.first;
    final rest = entries.skip(1).take(size - 1).toList();
    ResumeTile tile(ProgressEntry e, {bool large = false}) => ResumeTile(
      entry: e,
      tmdb: tmdb,
      large: large,
      focused: large && previewFocus ? true : null,
      // Açılışta kumanda odağı büyük kartta (vitrin düğmesinin yerine).
      autofocus: large && !previewFocus,
      onPressed: () => onResume?.call(e),
    );
    if (phone) {
      return Column(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: tile(first, large: true)),
          if (rest.isNotEmpty) ...[
            SizedBox(height: gap),
            SizedBox(
              height: 112,
              child: Row(
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: tile(rest[i])),
                  ],
                  // Tek küçük kart yarım genişlikte kalır.
                  if (rest.length == 1) ...[SizedBox(width: gap), const Spacer()],
                ],
              ),
            ),
          ],
        ],
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: tile(first, large: true)),
          if (rest.isNotEmpty) ...[
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) SizedBox(height: gap),
                    Expanded(child: tile(rest[i])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panonun kartı: tam kaplayan görsel, alttan perde; üstünde rozet, ad,
/// ayrıntı ve izleme ilerlemesi.
class ResumeTile extends StatelessWidget {
  const ResumeTile({
    super.key,
    required this.entry,
    this.tmdb,
    this.large = false,
    this.focused,
    this.autofocus = false,
    this.onPressed,
  });

  final ProgressEntry entry;
  final Tmdb? tmdb;

  /// Büyük kart: iri ad, "DEVAM ET" rozeti; odakta daha az büyür (kenara taşmasın).
  final bool large;
  final bool? focused;
  final bool autofocus;
  final VoidCallback? onPressed;

  /// Kartın ayrıntı satırı, örn. "Sezon 2 · Bölüm 5 · 1 sa 18 dk kaldı".
  static String detailOf(ProgressEntry e) => switch (e.episode) {
    final ep? when e.finished => 'S${ep.season} · B${ep.episode} bitti · sıradaki bölüm',
    final ep? => 'Sezon ${ep.season} · Bölüm ${ep.episode} · ${e.remaining}',
    null => 'Film · ${e.remaining}',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(large ? RedoxRadius.xl : RedoxRadius.lg);
    final ep = entry.episode;
    final next = ep != null && entry.finished;
    final name = ContinueCard.nameOf(entry);
    final badge = switch (ep) {
      _ when next => const StatusBadge(label: 'SIRADAKİ', tone: BadgeTone.amber),
      null => const StatusBadge(label: 'FİLM', tone: BadgeTone.gold),
      _ => large ? const StatusBadge(label: 'DEVAM ET') : null,
    };
    final fill = next ? RedoxSeeds.amber : (ep == null ? RedoxSeeds.gold : RedoxRoles.primaryContainer);
    return LayoutBuilder(
      builder: (context, box) => FocusGlow(
        borderRadius: radius,
        focused: focused,
        scale: large ? 1.03 : null,
        builder: (context, active) => Material(
          color: RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: active ? BorderSide.none : RedoxElevation.restingBorder,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ContinueBackdrop(
                  name: name,
                  series: ep != null,
                  poster: entry.poster,
                  tmdb: tmdb,
                  width: box.maxWidth,
                  showInitials: false,
                ),
                // Okunurluk: alttan obsidyen perde.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0, 0.55, 1],
                      colors: [RedoxSeeds.obsidian, Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                ),
                // Rozet sol üstte: küçük kartta (TV'de ~108 dp) yazılara yer kalsın.
                if (badge != null) Positioned(top: large ? 16 : 10, left: large ? 16 : 12, child: badge),
                Padding(
                  padding: large ? const EdgeInsets.all(16) : const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (large ? t.headlineMedium : t.titleMedium)!.copyWith(color: RedoxRoles.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        large ? detailOf(entry) : _short(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                      if (!next) ...[
                        SizedBox(height: large ? 10 : 8),
                        RedoxProgressBar(value: entry.fraction, color: fill, height: large ? 6 : 4),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Küçük kartta kısa ayrıntı: dizide "S2 · B5", filmde kalan süre.
  static String _short(ProgressEntry e) => switch (e.episode) {
    final ep? when e.finished => 'S${ep.season} · B${ep.episode} bitti',
    final ep? => 'S${ep.season} · B${ep.episode} · ${e.remaining}',
    null => e.remaining,
  };
}
