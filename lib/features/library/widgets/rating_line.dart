import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_icon.dart';

/// "2021 · ★ 7.3 TMDB · ★ 8.8 IMDb · Komedi": yıl, puanlar (yıldız ikonu; Sora'da
/// ★ yok) ve verilen ekler. IMDb puanı gelince satıra eklenir ([imdb]).
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.info, this.extra = const [], required this.style, this.imdb});

  final TmdbInfo? info;
  final List<String> extra;
  final TextStyle style;

  /// IMDb puanı (OMDb); anahtar yoksa null.
  final Future<double?>? imdb;

  InlineSpan _score(double value, String source) => TextSpan(
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
      TextSpan(text: ' ${value.toStringAsFixed(1)} $source'),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      imdb == null ? _line(null) : FutureBuilder(future: imdb, builder: (context, snap) => _line(snap.data));

  Widget _line(double? imdbScore) {
    final parts = <InlineSpan>[
      if (info?.year case final y?) TextSpan(text: '$y'),
      if (info?.rating case final r?) _score(r, 'TMDB'),
      if (imdbScore != null) _score(imdbScore, 'IMDb'),
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
