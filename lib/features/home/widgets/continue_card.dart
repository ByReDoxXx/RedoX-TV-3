import 'package:flutter/material.dart';

import '../../../core/content/tmdb.dart';
import '../../../core/content/watch_progress.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/channel_card.dart';
import '../../../core/ui/status_badge.dart';

/// Anasayfa "İzlemeye devam et" ve "Sıradaki bölümler" kartı: kanal kartının
/// düzeni; görsel TMDB arka planı (16:9), yoksa listedeki afiş. Filmde temiz
/// ad ve kalan süre, dizide "Sezon 2 · Bölüm 3"; bitmiş bölümde sıradaki
/// bölüm önerilir.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.entry, required this.width, this.tmdb, this.onPressed});

  final ProgressEntry entry;
  final double width;
  final Tmdb? tmdb;
  final VoidCallback? onPressed;

  /// Karttaki ad: dizide dizi adı, filmde yıl ve etiketleri ayıklanmış ad.
  static String nameOf(ProgressEntry e) {
    if (e.episode case final ep?) return ep.series;
    final (name, _) = Tmdb.cleanName(e.title);
    return name.isEmpty ? e.title : name;
  }

  @override
  Widget build(BuildContext context) {
    final ep = entry.episode;
    final name = nameOf(entry);
    final next = ep != null && entry.finished;
    return ChannelCard(
      width: width,
      channelName: ep == null ? 'Film' : name,
      programTitle: switch (ep) {
        _ when next => 'Sıradaki bölüm',
        final e? => 'Sezon ${e.season} · Bölüm ${e.episode}',
        null => name,
      },
      timeRange: next ? 'S${ep.season} · B${ep.episode} bitti' : entry.remaining,
      progress: next ? 0 : entry.fraction,
      accent: next ? CardAccent.amber : (ep == null ? CardAccent.gold : CardAccent.crimson),
      badge: next ? const StatusBadge(label: 'SIRADAKİ', tone: BadgeTone.amber) : null,
      artwork: ContinueBackdrop(name: name, series: ep != null, poster: entry.poster, tmdb: tmdb, width: width),
      onPressed: onPressed,
    );
  }
}

/// Devam kartlarının görseli: TMDB arka planı, yoksa listedeki afiş.
class ContinueBackdrop extends StatelessWidget {
  const ContinueBackdrop({
    super.key,
    required this.name,
    required this.series,
    required this.width,
    this.poster,
    this.tmdb,
    this.showInitials = true,
  });

  /// Görsel yokken baş harfler (panoda yazıların üstüne biniyordu: kapalı).
  final bool showInitials;

  final String name;
  final bool series;
  final double width;
  final String? poster;
  final Tmdb? tmdb;

  @override
  Widget build(BuildContext context) {
    final fallback = ArtworkFallback(name: name, showInitials: showInitials);
    // Zayıf TV belleği: görsel kart boyunda çözülür.
    final cache = (width * MediaQuery.devicePixelRatioOf(context)).round();
    Widget image(String? src) => src == null
        ? fallback
        : Image.network(src, fit: BoxFit.cover, cacheWidth: cache, errorBuilder: (_, _, _) => fallback);
    final tmdb = this.tmdb;
    if (tmdb == null) return image(poster);
    return FutureBuilder(
      future: tmdb.find(name, series: series),
      builder: (context, snap) => image(snap.data?.backdrop ?? poster ?? snap.data?.poster),
    );
  }
}
