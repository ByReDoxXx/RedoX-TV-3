import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_icon.dart';

/// "2021 · ★ 7.3 TMDB · Komedi": yıl, puan (yıldız ikonu; Sora'da ★ yok) ve
/// verilen ekler.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.info, this.extra = const [], required this.style});

  final TmdbInfo? info;
  final List<String> extra;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final parts = <InlineSpan>[
      if (info?.year case final y?) TextSpan(text: '$y'),
      if (info?.rating case final r?)
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RedoxIcon(
                RedoxIcons.star,
                filled: true,
                size: (style.fontSize ?? 16) * 1.1,
                color: style.color ?? RedoxRoles.tertiary,
              ),
            ),
            TextSpan(text: ' ${r.toStringAsFixed(1)} TMDB'),
          ],
        ),
      for (final e in extra) TextSpan(text: e),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, p) in parts.indexed) ...[if (i > 0) const TextSpan(text: '  ·  '), p],
        ],
      ),
      style: style,
    );
  }
}
