import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/content/channel_folder.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/content/tmdb.dart';
import '../../../core/content/watch_progress.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';
import '../../library/widgets/rating_line.dart';
import '../../library/widgets/tmdb_poster.dart';
import 'vod_title.dart';

// TV film/dizi oynatıcısının katmanları (B tasarımı: afişli kart).

/// Sol üstte film/dizi bilgisi: duraklatınca ([full]) afiş, ad, bilgi ve
/// özet (TMDB); oynarken çubukla birlikte yalnız ad ve alt satır.
class VodInfo extends StatelessWidget {
  const VodInfo({super.key, required this.channel, required this.series, this.tmdb, this.full = false});

  final LiveChannel channel;
  final bool series;
  final Tmdb? tmdb;
  final bool full;

  static const posterWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = vodTitle(channel, series: series);
    final lookup = tmdb?.find(series ? title.title : channel.name, series: series);
    return FutureBuilder(
      future: lookup ?? Future<TmdbInfo?>.value(),
      builder: (context, snap) {
        final info = snap.data;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(label: series ? 'DİZİ' : 'FİLM', tone: series ? BadgeTone.live : BadgeTone.gold),
            const SizedBox(height: 8),
            Text(
              title.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w800),
            ),
            if (title.subtitle.isNotEmpty)
              Text(
                title.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall!.copyWith(color: series ? RedoxRoles.tertiary : RedoxRoles.onSurfaceVariant),
              ),
            // Yalnız puan (yıl alt satırda); Sora'da ★ yok, ikonla çizilir.
            if (info?.rating case final r?)
              RatingLine(
                info: TmdbInfo(id: info!.id, title: info.title, rating: r),
                style: t.bodySmall!.copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w700),
              ),
            if (full && (info?.overview.isNotEmpty ?? false)) ...[
              const SizedBox(height: 10),
              Text(
                info!.overview,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant, height: 1.45),
              ),
            ],
          ],
        );
        if (!full) return text;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.lg),
              child: SizedBox(
                width: posterWidth,
                height: posterWidth * 3 / 2,
                child: TmdbPoster(name: title.title, url: channel.logoUrl ?? info?.poster),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: text),
          ],
        );
      },
    );
  }
}

/// Dizide ▲ ile açılan bölüm şeridi: sezonun bölümleri (oynatıcının
/// listesi), izlenenler ve oynayan (kızıl çerçeve) işaretli; ◄► gezer, OK
/// bölümü açar, ▼ ya da Geri kapatır. Odak açılışta sıradaki bölümdedir.
class EpisodeStrip extends StatelessWidget {
  const EpisodeStrip({
    super.key,
    required this.episodes,
    required this.current,
    required this.onSelect,
    required this.onClose,
    this.progress,
  });

  final List<LiveChannel> episodes;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  final WatchProgress? progress;

  static const tileWidth = 150.0;
  static const thumbHeight = 84.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final season = ChannelFolder.parseEpisode(episodes[current].name)?.season;
    final focus = current + 1 < episodes.length ? current + 1 : current;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: season == null ? 'Bölümler' : 'Sezon $season'),
                TextSpan(
                  // Sora'da ok işaretleri yok: sözle.
                  text: '   Sağ/sol: bölüm · OK: oynat · Aşağı: kapat',
                  style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
              ],
            ),
            style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < episodes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  _EpisodeTile(
                    episode: episodes[i],
                    entry: progress?.of(episodes[i].streams.firstOrNull ?? ''),
                    playing: i == current,
                    autofocus: i == focus,
                    onPressed: () => onSelect(i),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.playing,
    required this.autofocus,
    required this.onPressed,
    this.entry,
  });

  final LiveChannel episode;
  final ProgressEntry? entry;
  final bool playing;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ep = ChannelFolder.parseEpisode(episode.name);
    final radius = BorderRadius.circular(RedoxRadius.md);
    final e = entry;
    final watched = e != null && e.finished;
    final state = playing ? 'oynatılıyor' : (watched ? 'izlendi' : e?.remaining);
    return SizedBox(
      width: EpisodeStrip.tileWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusGlow(
            borderRadius: radius,
            builder: (context, active) => Material(
              color: RedoxRoles.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: playing ? const BorderSide(color: RedoxRoles.primaryContainer, width: 3) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                autofocus: autofocus,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: SizedBox(
                  width: EpisodeStrip.tileWidth,
                  height: EpisodeStrip.thumbHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (episode.logoUrl case final url?)
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ArtworkFallback(name: ep?.series ?? episode.name),
                        )
                      else
                        ArtworkFallback(name: ep?.series ?? episode.name, showInitials: false),
                      if (e != null)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 7,
                          child: RedoxProgressBar(value: watched ? 1 : e.fraction, height: 4),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [if (ep != null) 'B${ep.episode}', ?state].join(' · '),
            maxLines: 1,
            style: t.labelMedium!.copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w700),
          ),
          Text(
            ep == null ? episode.name : (ep.title.isEmpty ? 'Bölüm ${ep.episode}' : ep.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
