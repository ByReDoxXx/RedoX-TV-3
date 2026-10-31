import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_type.dart';
import 'focus_glow.dart';
import 'redox_progress_bar.dart';

/// Kart vurgusu: kanal adı (metin) ve ilerleme dolgusu (metin dışı) renkleri.
/// Metin renkleri kartta >= 4,5:1, dolgular izde >= 3:1 (redox_contrast_test.dart).
enum CardAccent {
  crimson(RedoxRoles.primary, RedoxRoles.primaryContainer),
  amber(RedoxRoles.secondary, RedoxSeeds.amber),
  gold(RedoxRoles.tertiary, RedoxSeeds.gold);

  const CardAccent(this.text, this.fill);

  final Color text;
  final Color fill;
}

/// Canlı kanal kartı (zip'teki Anasayfa tasarımından): üstte 16:9 görsel,
/// altta kanal adı, program, saat ve yayın ilerlemesi.
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channelName,
    required this.programTitle,
    required this.timeRange,
    required this.progress,
    required this.artwork,
    this.number,
    this.genre,
    this.accent = CardAccent.crimson,
    this.badge,
    this.width = 200,
    this.onPressed,
    this.focused,
  });

  final String channelName;
  final String programTitle;

  /// Örn. "20:00 – 22:30".
  final String timeRange;
  final String? genre;

  /// TKGS kanal numarası.
  final int? number;
  final double progress;
  final Widget artwork;
  final CardAccent accent;
  final Widget? badge;
  final double width;
  final VoidCallback? onPressed;
  final bool? focused;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return SizedBox(
      width: width,
      child: FocusGlow(
        borderRadius: radius,
        focused: focused,
        builder: (context, active) => Material(
          color: active ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: active ? BorderSide.none : RedoxElevation.restingBorder,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      artwork,
                      if (badge != null) Positioned(top: 8, left: 8, child: badge!),
                      if (number != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _NumberTag(number: number!),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channelName,
                        style: t.labelMedium!.copyWith(color: accent.text, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        programTitle,
                        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        genre == null ? timeRange : '$timeRange · $genre',
                        style: t.bodySmall!.copyWith(
                          color: RedoxRoles.onSurfaceVariant,
                          fontFeatures: RedoxType.tabular,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      RedoxProgressBar(value: progress, color: accent.fill),
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
}

class _NumberTag extends StatelessWidget {
  const _NumberTag({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Text(
        number.toString().padLeft(3, '0'),
        style: style.copyWith(
          color: RedoxRoles.tertiary,
          fontWeight: FontWeight.w800,
          fontFeatures: RedoxType.tabular,
        ),
      ),
    );
  }
}
