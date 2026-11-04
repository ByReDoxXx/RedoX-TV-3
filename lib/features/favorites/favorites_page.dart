import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/series_catalog.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/navigation/destinations.dart';
import '../../core/navigation/double_back_to_exit.dart';
import '../../core/playback/radio_controller.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/long_press_select.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../library/film_detail_page.dart';
import '../library/series_detail_page.dart';
import '../library/widgets/tmdb_poster.dart';
import '../radio/radio_player_page.dart';
import '../search/search_page.dart';
import '../settings/widgets/setting_tiles.dart';
import 'widgets/favorite_poster_grid.dart';
import 'widgets/favorite_row.dart';
import 'widgets/favorites_empty.dart';
import 'widgets/favorites_search.dart';

/// Favori sırası. "Sıram" elle dizilen; Film ve Dizi'de eklenme sırasıdır.
enum FavoriteSort {
  custom('Sıram'),
  name('A-Z'),
  number('Kanal no'),
  category('Kategori');

  const FavoriteSort(this.label);

  final String label;
}

/// Favorilerin sekmesi: kayıt türüne göre (kullanıcı isteği: Kaynaklar'dan
/// eklenen dizi Dizi'ye, film Film'e, televizyon Televizyon'a; "Kaynaklar"
/// sekmesi kalktı).
enum FavoriteTab {
  tv('Televizyon', 'TV'),
  radio('Radyo', 'Radyo'),
  film('Film', 'Film'),
  series('Dizi', 'Dizi');

  const FavoriteTab(this.label, this.short);

  final String label;

  /// Telefonda dört sekme bir satıra sığsın diye.
  final String short;
}

/// Televizyon ve Radyo satırı. Televizyon'da uygulamanın kanalları (numarayla)
/// ve Kaynaklar'dan eklenen canlı TV kayıtları (adresle) birlikte durur.
class _Entry {
  const _Entry(this.channel, {this.fromSource = false});

  final LiveChannel channel;
  final bool fromSource;

  String get key => fromSource ? channel.streams.first : 'no:${channel.number}';
}

/// Favoriler. **Televizyon ve Radyo:** satırlar; kumandada uzun OK ile,
/// dokunmatikte sürükle-bırakla taşınır. **Film ve Dizi:** afiş ızgarası; dizi
/// bölümleri diziye göre toplanır, dokunmatikte sürükle-bırakla dizilir; uzun OK
/// ve afişin köşesindeki düğme çıkarır. Arama bütün sekmeleri süzer.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.favorites,
    required this.channels,
    required this.clock,
    required this.profileName,
    this.radio,
    this.sources,
    this.tmdb,
    this.onWatch,
    this.onWatchSource,
    this.onGo,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final Favorites favorites;

  /// TV kanalları (yayın akışıyla; şu anki program buradan).
  final List<LiveChannel> channels;
  final RadioController? radio;
  final ValueChanged<LiveChannel>? onWatch;

  /// Eski favorilerin türünü bulmak için; null ise adlarından tahmin edilir.
  final UserSources? sources;

  /// Afiş, özet ve puan; null ise film doğrudan oynar.
  final Tmdb? tmdb;

  /// Kaynaklar'dan eklenen kayıt listeyle oynatıcıda açılır.
  final Future<void> Function(List<LiveChannel> list, int index, SourceKind kind)? onWatchSource;

  /// Boş sekmedeki düğme: kaydın ekleneceği bölüme gider.
  final ValueChanged<AppSection>? onGo;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  static const ringRoom = 12.0;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  FavoriteTab _tab = FavoriteTab.tv;
  FavoriteSort _sort = FavoriteSort.custom;

  /// Arama metni; süzülürken sıra değiştirilemez.
  String _query = '';

  /// Taşınan satır ([_Entry.key]). ▲▼ taşır, OK/Geri bitirir.
  String? _moving;

  Favorites get _fav => widget.favorites;

  bool get _posters => _tab == FavoriteTab.film || _tab == FavoriteTab.series;

  DoubleBackToExitState? _back;

  bool _onBack() {
    if (_moving == null || !mounted) return false;
    setState(() => _moving = null);
    return true;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_classifyOld());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final back = DoubleBackToExit.maybeOf(context);
    if (back != _back) {
      _back?.removeHandler(_onBack);
      _back = back?..addHandler(_onBack);
    }
  }

  @override
  void dispose() {
    _back?.removeHandler(_onBack);
    super.dispose();
  }

  /// Türü kayıtlı olmayan eski favoriler kaynak listelerinde aranır; bulunana
  /// dek adından tahmin edilen sekmede görünür.
  Future<void> _classifyOld() async {
    final sources = widget.sources;
    if (sources == null) return;
    final wanted = _fav.unclassified;
    if (wanted.isEmpty) return;
    final found = <String, FavoriteOrigin>{};
    var complete = true;
    for (final s in sources.items) {
      try {
        for (final c in await sources.channels(s)) {
          final url = c.streams.first;
          if (wanted.contains(url)) found[url] = (kind: s.kind, sourceId: s.id, category: c.category);
        }
      } on Object {
        complete = false;
      }
    }
    if (mounted) _fav.classify(found, complete: complete);
  }

  bool get _searching => _query.trim().isNotEmpty;

  bool _matches(Iterable<String?> texts) {
    final q = SearchPage.fold(_query.trim());
    return q.isEmpty || texts.nonNulls.any((x) => SearchPage.fold(x).contains(q));
  }

  List<FavoriteSort> get _sorts => _posters ? const [FavoriteSort.custom, FavoriteSort.name] : FavoriteSort.values;

  void _nextSort() => setState(() {
    final sorts = _sorts;
    _sort = sorts[(sorts.indexOf(_sort) + 1) % sorts.length];
    _moving = null;
  });

  // Televizyon ve Radyo

  List<_Entry> _entries() => _entriesOf(_tab);

  List<_Entry> _entriesOf(FavoriteTab tab) {
    final radio = tab == FavoriteTab.radio;
    final source = radio ? widget.radio?.stations ?? const <LiveChannel>[] : widget.channels;
    final byNumber = {for (final c in source) c.number: c};
    final list = [
      for (final n in radio ? _fav.radios : _fav.channels)
        if (byNumber[n] case final c?) _Entry(c),
      if (!radio)
        for (final c in _fav.sourceChannels(SourceKind.live)) _Entry(c, fromSource: true),
    ]..retainWhere((e) => _matches([e.channel.name, e.channel.category, e.channel.programTitle]));
    switch (_sort) {
      case FavoriteSort.custom:
        break;
      case FavoriteSort.name:
        list.sort((a, b) => a.channel.name.toLowerCase().compareTo(b.channel.name.toLowerCase()));
      case FavoriteSort.number:
        list.sort((a, b) => a.channel.number.compareTo(b.channel.number));
      case FavoriteSort.category:
        list.sort((a, b) => a.channel.category.compareTo(b.channel.category));
    }
    return list;
  }

  /// Satırı taşır. Uygulama kanalları ve kaynak kayıtları ayrı saklandığından
  /// kendi öbeğinin içinde kalır.
  void _move(List<_Entry> entries, _Entry e, int to) {
    if (_tab == FavoriteTab.radio) return _fav.moveRadio(e.channel.number, to);
    final numbered = entries.where((x) => !x.fromSource).length;
    if (e.fromSource) {
      _fav.moveSource(e.channel.streams.first, to - numbered);
    } else {
      _fav.moveChannel(e.channel.number, to.clamp(0, numbered - 1));
    }
  }

  void _remove(_Entry e) {
    if (e.fromSource) {
      _fav.forgetSources({e.channel.streams.first});
    } else if (_tab == FavoriteTab.radio) {
      _fav.toggleRadio(e.channel.number);
    } else {
      _fav.toggleChannel(e.channel.number);
    }
  }

  Future<void> _open(_Entry e, List<_Entry> entries) async {
    if (e.fromSource) {
      final list = [
        for (final x in entries)
          if (x.fromSource) x.channel,
      ];
      await widget.onWatchSource?.call(list, list.indexOf(e.channel), SourceKind.live);
      return;
    }
    if (_tab == FavoriteTab.tv) {
      widget.onWatch?.call(e.channel);
      return;
    }
    final radio = widget.radio;
    if (radio == null) return;
    if (e.channel != radio.current) unawaited(radio.play(e.channel));
    await Navigator.of(context)
        .push(RadioPlayerPage.route(radio: radio, stations: [for (final x in entries) x.channel], favorites: _fav));
  }

  /// Taşıma kipinde ▲▼ taşır, OK bitirir.
  KeyEventResult _onMoveKey(FocusNode _, KeyEvent e) {
    final moving = _moving;
    if (moving == null || e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    final entries = _entries();
    final i = entries.indexWhere((x) => x.key == moving);
    if (i < 0) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (i > 0) _move(entries, entries[i], i - 1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (i < entries.length - 1) _move(entries, entries[i], i + 1);
    } else if (LongPressSelect.isSelect(key) && e is KeyDownEvent) {
      setState(() => _moving = null);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      // Taşırken satırdan çıkılmaz.
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// İlk kayıt yalnız kumandada ve aramasızken odak alır; yoksa yazarken kutudan
  /// odak çalardı.
  bool get _autofocusFirst => _tv && !_searching;

  bool get _tv => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;

  Widget _row(List<_Entry> entries, int i, bool phone, {bool drag = false}) {
    final e = entries[i];
    final moving = _moving == e.key;
    return FavoriteRow(
      channel: e.channel,
      moving: moving,
      onLongPress: drag || _searching
          ? null
          : () => setState(() {
              if (moving) {
                _moving = null;
              } else {
                _sort = FavoriteSort.custom;
                _moving = e.key;
              }
            }),
      position: i + 1,
      radio: _tab == FavoriteTab.radio,
      compact: phone,
      autofocus: _autofocusFirst && i == 0,
      handle: drag
          ? ReorderableDragStartListener(
              index: i,
              child: Semantics(
                label: 'Sürükleyerek taşı',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: RedoxIcon(RedoxIcons.menu, color: RedoxRoles.onSurfaceVariant),
                ),
              ),
            )
          : null,
      onPressed: () => moving ? setState(() => _moving = null) : unawaited(_open(e, entries)),
      onUp: i > 0 ? () => _move(entries, e, i - 1) : null,
      onDown: i < entries.length - 1 ? () => _move(entries, e, i + 1) : null,
      onRemove: () => _remove(e),
    );
  }

  Widget _rows(EdgeInsets padding, bool phone, bool touch) {
    final entries = _entries();
    if (entries.isEmpty) return _empty();
    final listPadding = EdgeInsets.fromLTRB(
      padding.left - FavoritesPage.ringRoom,
      6,
      padding.right,
      phone ? padding.bottom : 16,
    );
    if (touch && _sort == FavoriteSort.custom && !_searching) {
      return ReorderableListView.builder(
        padding: listPadding,
        buildDefaultDragHandles: false,
        itemCount: entries.length,
        onReorderItem: (from, to) => _move(entries, entries[from], to),
        itemBuilder: (context, i) => Padding(
          key: ValueKey(entries[i].key),
          padding: const EdgeInsets.fromLTRB(FavoritesPage.ringRoom, 0, 0, 8),
          // Tutamaç hemen, satırın kendisi basılı tutunca sürüklenir.
          child: ReorderableDelayedDragStartListener(
            index: i,
            child: SizedBox(height: FavoriteRow.height, child: _row(entries, i, phone, drag: true)),
          ),
        ),
      );
    }
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onMoveKey,
      child: ListView.builder(
        padding: listPadding,
        itemExtent: FavoriteRow.height + 8,
        itemCount: entries.length,
        // Taşınan satırın odağı onunla gider (anahtar: kimlik).
        findChildIndexCallback: (key) {
          final i = entries.indexWhere((x) => ValueKey(x.key) == key);
          return i < 0 ? null : i;
        },
        itemBuilder: (context, i) => Padding(
          key: ValueKey(entries[i].key),
          padding: const EdgeInsets.fromLTRB(FavoritesPage.ringRoom, 0, 0, 8),
          child: _row(entries, i, phone),
        ),
      ),
    );
  }

  // Film ve Dizi

  /// Sürüklenen kayıt hedefin yerine geçer; diğerleri kayar.
  List<T> _reordered<T>(List<T> list, T moved, T target) {
    final to = list.indexOf(target);
    return List.of(list)
      ..remove(moved)
      ..insert(to, moved);
  }

  bool get _canDrag => _sort == FavoriteSort.custom && !_searching;

  List<LiveChannel> _filmList() =>
      _fav.sourceChannels(SourceKind.film)..retainWhere((c) => _matches([c.name, c.category]));

  Widget _films(EdgeInsets padding, bool phone) {
    final films = _filmList();
    if (films.isEmpty) return _empty();
    if (_sort == FavoriteSort.name) films.sort((a, b) => _title(a).toLowerCase().compareTo(_title(b).toLowerCase()));
    return FavoritePosterGrid<LiveChannel>(
      items: films,
      padding: padding,
      phone: phone,
      autofocusFirst: _autofocusFirst,
      onReorder: !_canDrag
          ? null
          : (moved, target) => _fav.reorderSources(SourceKind.film, [
              for (final c in _reordered(films, moved, target)) c.streams.first,
            ]),
      keyOf: (c) => c.streams.first,
      titleOf: _title,
      artworkOf: (c) => TmdbPoster(name: c.name, url: c.logoUrl, tmdb: widget.tmdb),
      onOpen: (c) => _openFilm(films, films.indexOf(c)),
      onRemove: (c) => unawaited(_confirmRemove(_title(c), {c.streams.first})),
    );
  }

  /// Afişte temiz ad ("|MULTI| Ad (2023) [4K]" etiketleri kartı dolduruyordu).
  String _title(LiveChannel c) => switch (Tmdb.cleanName(c.name).$1) {
    '' => c.name,
    final name => name,
  };

  Future<void> _playFilm(List<LiveChannel> films, int i) async => widget.onWatchSource?.call(films, i, SourceKind.film);

  void _openFilm(List<LiveChannel> films, int i) {
    final tmdb = widget.tmdb;
    if (tmdb == null) return unawaited(_playFilm(films, i));
    unawaited(Navigator.of(context).push(_filmRoute(tmdb, films, i)));
  }

  Route<void> _filmRoute(Tmdb tmdb, List<LiveChannel> films, int i) => FilmDetailPage.route(
    film: films[i],
    tmdb: tmdb,
    onWatch: () => unawaited(_playFilm(films, i)),
    library: films,
    onSimilar: (c) => unawaited(Navigator.of(context).pushReplacement(_filmRoute(tmdb, films, films.indexOf(c)))),
  );

  /// Bölümler diziye göre toplanır; listenin kaynağı korunur (dizi kilidi).
  List<Series> _seriesList() {
    final bySource = <String, List<LiveChannel>>{};
    final order = <String, int>{};
    final items = _fav.sourcesOf(SourceKind.series);
    final channels = _fav.sourceChannels(SourceKind.series);
    for (final (i, item) in items.indexed) {
      bySource.putIfAbsent(item.sourceId ?? 'favori', () => []).add(channels[i]);
      order[item.url] = i;
    }
    final catalog = SeriesCatalog.build([for (final MapEntry(:key, :value) in bySource.entries) (key, value)]);
    catalog.retainWhere(
      (s) => _matches([
        s.name,
        s.category,
        for (final season in s.seasons)
          for (final e in s.episodes(season)) e.channel.name,
      ]),
    );
    if (_sort == FavoriteSort.custom) {
      int first(Series s) => [
        for (final season in s.seasons)
          for (final e in s.episodes(season)) order[e.channel.streams.first] ?? 0,
      ].reduce((a, b) => a < b ? a : b);
      catalog.sort((a, b) => first(a).compareTo(first(b)));
    }
    return catalog;
  }

  Widget _series(EdgeInsets padding, bool phone) {
    final list = _seriesList();
    if (list.isEmpty) return _empty();
    return FavoritePosterGrid<Series>(
      items: list,
      padding: padding,
      phone: phone,
      autofocusFirst: _autofocusFirst,
      onReorder: !_canDrag
          ? null
          : (moved, target) => _fav.reorderSources(SourceKind.series, [
              for (final s in _reordered(list, moved, target))
                for (final season in s.seasons)
                  for (final e in s.episodes(season)) e.channel.streams.first,
            ]),
      keyOf: (s) => s.name,
      titleOf: (s) => s.name,
      badgeOf: (s) => s.shortSummary,
      artworkOf: (s) => TmdbPoster(name: s.name, url: s.poster, tmdb: widget.tmdb, series: true),
      onOpen: (s) => unawaited(
        SeriesDetailPage.open(
          context,
          s,
          tmdb: widget.tmdb,
          favorites: _fav,
          onWatch: (episodes, i) async => widget.onWatchSource?.call(episodes, i, SourceKind.series),
        ),
      ),
      onRemove: (s) => unawaited(
        _confirmRemove(s.name, {
          for (final season in s.seasons)
            for (final e in s.episodes(season)) e.channel.streams.first,
        }),
      ),
    );
  }

  Future<void> _confirmRemove(String title, Set<String> urls) async {
    final ok = await confirmSetting(
      context,
      title: 'Favorilerden çıkarılsın mı?',
      text: urls.length > 1 ? '$title: ${urls.length} bölüm çıkarılacak.' : title,
      yes: 'Çıkar',
    );
    if (ok) _fav.forgetSources(urls);
  }

  Widget _empty() => _searching
      ? FavoritesEmpty(
          icon: RedoxIcons.search,
          title: 'Bu sekmede sonuç yok',
          text: '"${_query.trim()}" için diğer sekmelere bakın ya da aramayı temizleyin.',
          action: 'Aramayı temizle',
          onAction: () => setState(() => _query = ''),
        )
      : _emptyTab();

  Widget _emptyTab() => switch (_tab) {
    FavoriteTab.tv => FavoritesEmpty(
      icon: RedoxIcons.television,
      title: 'Favori kanal yok',
      text: "Televizyon'da önizleme panelindeki kalbe ya da Kaynaklar'da canlı TV kaydının yıldızına basın.",
      action: "Televizyon'a git",
      onAction: widget.onGo == null ? null : () => widget.onGo!(AppSection.tv),
    ),
    FavoriteTab.radio => FavoritesEmpty(
      icon: RedoxIcons.radio,
      title: 'Favori istasyon yok',
      text: 'Radyo listesinde ya da kadranda kalbe basarak ekleyin.',
      action: "Radyo'ya git",
      onAction: widget.onGo == null ? null : () => widget.onGo!(AppSection.radio),
    ),
    FavoriteTab.film => FavoritesEmpty(
      icon: RedoxIcons.film,
      title: 'Favori film yok',
      text: "Kaynaklar'da bir filmin yıldızına basarak ekleyin.",
      action: "Kaynaklar'a git",
      onAction: widget.onGo == null ? null : () => widget.onGo!(AppSection.sources),
    ),
    FavoriteTab.series => FavoritesEmpty(
      icon: RedoxIcons.series,
      title: 'Favori dizi yok',
      text: "Kaynaklar'da ya da dizi sayfasında bir bölümün yıldızına basarak ekleyin.",
      action: "Kaynaklar'a git",
      onAction: widget.onGo == null ? null : () => widget.onGo!(AppSection.sources),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final tv = metrics.formFactor == FormFactor.tv;
    final padding = PageLayout.scrollPadding(context, metrics);
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _fav,
      builder: (context, _) {
        final seriesCount = _fav.sourcesOf(SourceKind.series).isEmpty ? 0 : _seriesList().length;
        final filmCount = _filmList().length;
        // Sayılar burada: favoriden çıkarınca çipteki sayı da güncellensin.
        final tabs = [
          (FavoriteTab.tv, _entriesOf(FavoriteTab.tv).length),
          if (widget.radio != null) (FavoriteTab.radio, _entriesOf(FavoriteTab.radio).length),
          // Arama sonuç bulmasa da sekme yerinde kalır.
          if (widget.sources != null || _fav.sourcesOf(SourceKind.film).isNotEmpty) (FavoriteTab.film, filmCount),
          if (widget.sources != null || _fav.sourcesOf(SourceKind.series).isNotEmpty) (FavoriteTab.series, seriesCount),
        ];
        final current = tabs.firstWhere((x) => x.$1 == _tab, orElse: () => tabs.first);
        final hint = !tv || current.$2 == 0 || _searching
            ? null
            : _posters
            ? 'Uzun OK: favorilerden çıkar'
            : 'Uzun OK: sırayı değiştir';
        final search = FavoritesSearch(
          query: _query,
          onChanged: (q) => setState(() {
            _query = q;
            _moving = null;
          }),
        );
        final sort = current.$2 > 1
            ? GlassButton(label: _sort.label, icon: RedoxIcons.tune, onPressed: _nextSort)
            : null;
        return Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: phone ? 0 : padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: AppHeader(
                  clock: widget.clock,
                  profileName: widget.profileName,
                  onHome: widget.onHome,
                  onMore: widget.onMore,
                  onProfile: widget.onProfile,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: padding.left - FavoritesPage.ringRoom, right: padding.right),
                child: Row(
                  children: [
                    Expanded(
                      child: ScrollHintRow(
                        padding: const EdgeInsets.fromLTRB(FavoritesPage.ringRoom, 16, 12, 6),
                        child: Row(
                          children: [
                            for (final (i, (tab, count)) in tabs.indexed) ...[
                              if (i > 0) SizedBox(width: phone ? 8 : 12),
                              CategoryChip(
                                label: phone ? tab.short : tab.label,
                                // Telefonda dört sekme sığsın: sayı yalnız seçilide.
                                count: phone && tab != _tab ? null : count,
                                selected: tab == _tab,
                                onPressed: () => setState(() {
                                  _tab = tab;
                                  _sort = FavoriteSort.custom;
                                  _moving = null;
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!phone) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: tv ? search : SizedBox(width: 220, child: search),
                      ),
                      if (sort != null) ...[
                        const SizedBox(width: 12),
                        Padding(padding: const EdgeInsets.only(top: 10), child: sort),
                      ],
                    ],
                  ],
                ),
              ),
              if (phone)
                Padding(
                  padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right, 4),
                  child: Row(
                    children: [
                      Expanded(child: search),
                      if (sort != null) ...[const SizedBox(width: 8), sort],
                    ],
                  ),
                ),
              Expanded(
                child: switch (_tab) {
                  FavoriteTab.film => _films(padding, phone),
                  FavoriteTab.series => _series(padding, phone),
                  _ => _rows(padding, phone, !tv),
                },
              ),
              if (hint != null)
                Padding(
                  padding: EdgeInsets.only(left: padding.left, top: 4),
                  child: Text(hint, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                ),
            ],
          ),
        );
      },
    );
  }
}
