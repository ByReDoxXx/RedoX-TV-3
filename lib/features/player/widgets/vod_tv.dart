import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/content/channel_folder.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/content/omdb.dart';
import '../../../core/content/tmdb.dart';
import '../../../core/content/watch_progress.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/decoded_size.dart';
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
                imdb: Omdb.shared?.ratingOf(tmdb!, info, series: series),
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

/// Dizide ▲ ile açılan bölüm şeridi: oynatıcının listesi sezon sezon, izlenenler
/// ve oynayan (kızıl çerçeve) işaretli. Birden çok sezon varsa üstte sekmeler: ▲
/// sekmeye çıkar, OK sezonu açar. ◄► gezer, OK bölümü açar, bölümdeyken ▼ ya da
/// Geri kapatır. Odak açılışta sıradaki bölümdedir.
class EpisodeStrip extends StatefulWidget {
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
  State<EpisodeStrip> createState() => _EpisodeStripState();
}

class _EpisodeStripState extends State<EpisodeStrip> {
  int? _seasonOf(int i) => ChannelFolder.parseEpisode(widget.episodes[i].name)?.season;

  late int? _season = _seasonOf(widget.current);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final seasons = {for (var i = 0; i < widget.episodes.length; i++) ?_seasonOf(i)}.toList()..sort();
    final shown = [
      for (var i = 0; i < widget.episodes.length; i++)
        if (_seasonOf(i) == _season) i,
    ];
    final current = widget.current;
    final focus = shown.contains(current + 1) ? current + 1 : (shown.contains(current) ? current : shown.firstOrNull);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (seasons.length > 1)
              for (final n in seasons) ...[
                _SeasonTab(season: n, selected: n == _season, onPressed: () => setState(() => _season = n)),
                const SizedBox(width: 8),
              ]
            else
              Text(
                _season == null ? 'Bölümler' : 'Sezon $_season',
                style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
              ),
            const Spacer(),
            // Sora'da ok işaretleri yok: sözle.
            Text(
              'Sağ/sol: bölüm · OK: oynat · Aşağı: kapat',
              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Sekmedeyken ▼ bölümlere iner: yalnız bölümdeyken kapatır.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
              widget.onClose();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (k, i) in shown.indexed) ...[
                  if (k > 0) const SizedBox(width: 14),
                  EpisodeTile(
                    key: ValueKey(i),
                    episode: widget.episodes[i],
                    entry: widget.progress?.of(widget.episodes[i].streams.firstOrNull ?? ''),
                    playing: i == current,
                    autofocus: i == focus && _season == _seasonOf(current),
                    onPressed: () => widget.onSelect(i),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonTab extends StatelessWidget {
  const _SeasonTab({required this.season, required this.selected, required this.onPressed});

  final int season;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RedoxRadius.full);
    return FocusGlow(
      borderRadius: radius,
      builder: (context, active) => Material(
        color: selected ? RedoxRoles.tertiary : (active ? RedoxRoles.surfaceContainerHighest : Colors.transparent),
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              'Sezon $season',
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: selected ? RedoxRoles.onTertiary : RedoxRoles.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm karosu (kumandada şerit, dokunmatikte panel).
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.playing,
    required this.onPressed,
    this.autofocus = false,
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
                          cacheHeight: decodedSize(context, EpisodeStrip.thumbHeight),
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
