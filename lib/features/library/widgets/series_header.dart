import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import 'rating_line.dart';
import 'tmdb_poster.dart';

/// Dizi klasörünün başında TMDB özeti: küçük afiş, ad, yıl, puan ve üç
/// satır özet. TMDB'de bulunamazsa görünmez.
class SeriesHeader extends StatelessWidget {
  const SeriesHeader({super.key, required this.name, required this.tmdb});

  final String name;
  final Tmdb tmdb;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder(
      future: tmdb.find(name, series: true),
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.md),
              child: SizedBox(
                width: 80,
                height: 120,
                child: TmdbPoster(name: name, url: info.poster),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
                  RatingLine(
                    info: info,
                    style: t.titleSmall!.copyWith(color: RedoxRoles.tertiary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
