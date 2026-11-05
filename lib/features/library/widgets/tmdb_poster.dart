import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/decoded_size.dart';

/// Kaydın afişi: listedeki görsel; yoksa TMDB afişi; o da yoksa baş harfler.
class TmdbPoster extends StatelessWidget {
  const TmdbPoster({super.key, required this.name, this.url, this.tmdb, this.series = false});

  final String name;

  /// Listedeki görsel (M3U tvg-logo, Xtream afişi).
  final String? url;
  final Tmdb? tmdb;
  final bool series;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final fallback = ArtworkFallback(name: name);
      final width = decodedSize(context, box.hasBoundedWidth ? box.maxWidth : _unboundedWidth);
      return _poster(
        (src) => Image.network(src, fit: BoxFit.cover, cacheWidth: width, errorBuilder: (_, _, _) => fallback),
        fallback,
      );
    },
  );

  /// Genişliği sınırsız yerleşimde afişin açılacağı genişlik (TMDB afişi kadar).
  static const _unboundedWidth = 342.0;

  Widget _poster(Widget Function(String src) image, Widget fallback) {
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
