import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/ui/artwork_fallback.dart';

/// Kaydın afişi: listedeki görsel; yoksa TMDB afişi; o da yoksa baş harfler.
class TmdbPoster extends StatelessWidget {
  const TmdbPoster({super.key, required this.name, this.url, this.tmdb, this.series = false});

  final String name;

  /// Listedeki görsel (M3U tvg-logo, Xtream afişi).
  final String? url;
  final Tmdb? tmdb;
  final bool series;

  @override
  Widget build(BuildContext context) {
    final fallback = ArtworkFallback(name: name);
    Widget image(String src) => Image.network(src, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
    if (url case final u?) return image(u);
    final tmdb = this.tmdb;
    if (tmdb == null) return fallback;
    return FutureBuilder(
      future: tmdb.find(name, series: series),
      builder: (context, snap) => switch (snap.data?.poster) {
        final p? => image(p),
        null => fallback,
      },
    );
  }
}
