import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/content/tmdb.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import 'tmdb_poster.dart';

/// "Benzerleri" rafı (film ayrıntısı): TMDB'nin önerilerinden kullanıcının
/// listesinde olanlar, afiş ve adla. Listede olmayan öneri gösterilmez
/// (oynatılamaz); hiçbiri yoksa raf hiç çizilmez.
class SimilarShelf extends StatelessWidget {
  const SimilarShelf({super.key, required this.items, required this.onOpen});

  final List<(TmdbInfo, LiveChannel)> items;
  final ValueChanged<LiveChannel> onOpen;

  /// Afiş genişliği (2:3).
  static const posterWidth = 92.0;

  /// Rafın yüksekliği: başlık, afiş ve ad.
  static const height = 28 + 4 + 8 + posterWidth * 3 / 2 + 8 + 24;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Benzerleri', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final (info, film) = items[i];
                return SizedBox(
                  width: posterWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FocusGlow(
                        borderRadius: radius,
                        builder: (context, active) => Material(
                          borderRadius: radius,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onOpen(film),
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            child: SizedBox(
                              width: posterWidth,
                              height: posterWidth * 3 / 2,
                              child: TmdbPoster(name: film.name, url: info.poster ?? film.logoUrl),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Dokunmatikte ad da açar (odak afiştedir).
                      GestureDetector(
                        onTap: () => onOpen(film),
                        child: Text(
                          info.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
