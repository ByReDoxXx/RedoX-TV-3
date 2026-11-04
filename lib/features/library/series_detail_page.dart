import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/content_locks.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/series_catalog.dart';
import '../../core/content/omdb.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/desktop_back_button.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../locks/lock_scope.dart';
import '../sources/widgets/channel_browser.dart';
import 'widgets/rating_line.dart';
import 'widgets/tmdb_poster.dart';

/// Dizi sayfası (kullanıcı isteği: "dizi sekmesini baştan tasarla"): arka
/// plan görseli, afiş, ad, yıl, puan, özet (TMDB) ve "İzle" (ilk bölüm);
/// sezon çipleri ve seçili sezonun bölümleri. Bölüm OK/dokunma ile sezonun
/// bölüm listesiyle oynar (oynatıcıda ▲▼ sonraki/önceki bölüm). TV'de bilgi
/// solda, bölümler sağda; telefonda alt alta.
class SeriesDetailPage extends StatefulWidget {
  const SeriesDetailPage({super.key, required this.series, this.tmdb, this.favorites, this.onWatch});

  final Series series;
  final Tmdb? tmdb;
  final Favorites? favorites;
  final Future<void> Function(List<LiveChannel> list, int index)? onWatch;

  /// Dizinin kilit anahtarı (kaynak klasörü: dizi adı).
  static String lockKey(Series s) => ContentLocks.folder(s.sourceId, [s.name]);

  /// Dizi sayfasını açar; kaynak ya da dizi kilitliyse önce PIN (Dizi
  /// bölümü ve arama).
  static Future<void> open(
    BuildContext context,
    Series series, {
    Tmdb? tmdb,
    Favorites? favorites,
    Future<void> Function(List<LiveChannel> list, int index)? onWatch,
  }) async {
    final gate = LockScope.maybeOf(context);
    final source = ContentLocks.folder(series.sourceId, const []);
    for (final k in [source, lockKey(series)]) {
      if (gate != null && gate.locks.blocks(k) && !await gate.pass(context, k)) return;
    }
    if (!context.mounted) return;
    final page = SeriesDetailPage(series: series, tmdb: tmdb, favorites: favorites, onWatch: onWatch);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Yeni rota kabuğun altında değil: kilit kapsamı taşınır.
        builder: (_) => gate == null ? page : LockScope(locks: gate.locks, profiles: gate.profiles, child: page),
      ),
    );
  }

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  late int _season = widget.series.seasons.first;
  late final Future<TmdbInfo?> _info = widget.tmdb?.find(widget.series.name, series: true) ?? Future.value();

  void _play(int season, int index) {
    final list = [for (final e in widget.series.episodes(season)) e.channel];
    unawaited(widget.onWatch?.call(list, index));
  }

  @override
  Widget build(BuildContext context) {
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder(
        future: _info,
        builder: (context, snap) {
          final info = snap.data;
          final bg = Theme.of(context).scaffoldBackgroundColor;
          final backdrop = switch (info?.backdrop) {
            final b? => Image.network(b, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            null => null,
          };
          // Telefonda görsel içerikle birlikte kayar (sabit kalınca bölüm
          // satırları görselin üstünden geçiyordu; Pixel'de görüldü).
          if (phone) return _phone(context, info, backdrop, bg);
          return Stack(
            fit: StackFit.expand,
            children: [
              ?backdrop,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg, bg.withValues(alpha: 0.93), bg.withValues(alpha: 0.6)],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              SafeArea(child: _wide(context, info)),
              const Positioned(left: 8, top: 8, child: DesktopBackButton()),
            ],
          );
        },
      ),
    );
  }

  Widget _wide(BuildContext context, TmdbInfo? info) => Padding(
    padding: const EdgeInsets.fromLTRB(48, 32, 48, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 340, child: SingleChildScrollView(child: _about(context, info, posterWidth: 150))),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _seasonChips(),
              const SizedBox(height: 12),
              Expanded(child: _episodeList(padding: const EdgeInsets.only(bottom: 32))),
            ],
          ),
        ),
      ],
    ),
  );

  /// Görselin telefondaki yüksekliği (durum çubuğu dahil).
  static const _backdropHeight = 300.0;

  Widget _phone(BuildContext context, TmdbInfo? info, Widget? backdrop, Color bg) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Stack(
          children: [
            if (backdrop != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _backdropHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    backdrop,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [bg.withValues(alpha: 0.3), bg.withValues(alpha: 0.5), bg],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassButton(
                      label: 'Geri',
                      icon: RedoxIcons.back,
                      iconOnly: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 90),
                  _about(context, info, posterWidth: 120),
                  const SizedBox(height: 20),
                  _seasonChips(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.builder(
          itemCount: widget.series.episodes(_season).length,
          itemBuilder: (context, i) => _episodeRow(i),
        ),
      ),
    ],
  );

  /// Afiş, ad, yıl/puan/kategori, özet ve düğmeler.
  Widget _about(BuildContext context, TmdbInfo? info, {required double posterWidth}) {
    final t = Theme.of(context).textTheme;
    final s = widget.series;
    final first = s.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.lg),
              child: SizedBox(
                width: posterWidth,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: TmdbPoster(name: s.name, url: s.poster ?? info?.poster),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info?.title ?? s.name, style: t.headlineMedium!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 6),
                  RatingLine(
                    info: info,
                    extra: [s.summary],
                    imdb: info == null ? null : Omdb.shared?.ratingOf(widget.tmdb!, info, series: true),
                    style: t.titleSmall!.copyWith(color: RedoxRoles.tertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (info != null && info.overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            info.overview,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant, height: 1.45),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PrimaryButton(
              label: s.seasons.length > 1 ? 'İzle · S${first.season} B${first.number}' : 'İzle · Bölüm ${first.number}',
              icon: RedoxIcons.play,
              autofocus: true,
              onPressed: widget.onWatch == null ? null : () => _play(first.season, 0),
            ),
            if (LockScope.maybeOf(context)?.profiles != null) LockButton(lockKey: SeriesDetailPage.lockKey(s)),
          ],
        ),
      ],
    );
  }

  Widget _seasonChips() {
    final seasons = widget.series.seasons;
    if (seasons.length < 2) {
      return Text(
        '${widget.series.episodeCount} bölüm',
        style: Theme.of(context).textTheme.titleMedium!.copyWith(color: RedoxRoles.onSurface),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, n) in seasons.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            CategoryChip(
              label: 'Sezon $n',
              count: widget.series.episodes(n).length,
              selected: n == _season,
              onPressed: () => setState(() => _season = n),
            ),
          ],
        ],
      ),
    );
  }

  Widget _episodeList({EdgeInsets padding = EdgeInsets.zero}) => ListView.builder(
    key: ValueKey(_season),
    padding: padding,
    itemCount: widget.series.episodes(_season).length,
    itemBuilder: (context, i) => _episodeRow(i),
  );

  Widget _episodeRow(int i) {
    final e = widget.series.episodes(_season)[i];
    final fav = widget.favorites;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _EpisodeRow(
        episode: e,
        onPressed: widget.onWatch == null ? null : () => _play(_season, i),
        favorite: fav?.hasSource(e.channel.streams.first),
        onFavorite: fav == null
            ? null
            : () => setState(
                () => fav.toggleSource(
                  FavoriteItem.of(e.channel, kind: SourceKind.series, sourceId: widget.series.sourceId),
                ),
              ),
      ),
    );
  }
}

/// Bölüm satırı: numara, ad, oynat ikonu; sağda favori yıldızı.
class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, this.onPressed, this.favorite, this.onFavorite});

  final Episode episode;
  final VoidCallback? onPressed;
  final bool? favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final row = FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Container(
                  width: 52,
                  alignment: Alignment.center,
                  child: Text(
                    '${episode.number}',
                    style: t.titleLarge!.copyWith(color: RedoxSeeds.gold, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    episode.title.isEmpty ? 'Bölüm ${episode.number}' : episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: RedoxIcon(RedoxIcons.play, filled: active, color: RedoxRoles.onSurfaceVariant, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (onFavorite == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        const SizedBox(width: 8),
        StarButton(favorite: favorite == true, onPressed: onFavorite),
      ],
    );
  }
}
