import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/content_locks.dart';
import '../../core/content/diagnostics.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/series_catalog.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/center_on_focus.dart';
import '../../core/ui/media_card.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../locks/lock_scope.dart';
import 'film_detail_page.dart';
import 'series_detail_page.dart';
import 'widgets/tmdb_poster.dart';

/// Film ve Dizi bölümleri: Ayarlar › Kaynak ekle'de Film ya da Dizi olarak
/// eklenen listeler (kullanıcı isteği). **Film:** bütün film kaynaklarının
/// kayıtları afiş ızgarasında, kategori çipleriyle. **Dizi:** kayıtlar dizi ›
/// sezon › bölüm klasörlerinde ("S01E02" ve "1. Sezon 2. Bölüm" adlardan,
/// yoksa grup adı ve "/"); birden çok kaynak varsa en üstte kaynak klasörleri.
/// OK/dokunma oynatır (kategori ya da klasörün kayıtlarıyla).
class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.kind,
    required this.sources,
    required this.clock,
    required this.profileName,
    this.favorites,
    this.tmdb,
    this.onWatch,
    this.onAdd,
    this.onHome,
    this.onMore,
    this.onProfile,
  }) : assert(kind != SourceKind.live);

  final SourceKind kind;
  final UserSources sources;
  final Favorites? favorites;

  /// Afiş, özet ve puan; null ise yalnız listedeki bilgiler.
  final Tmdb? tmdb;
  final Future<void> Function(List<LiveChannel> list, int index)? onWatch;

  /// Kaynak yokken "Kaynak ekle" (Ayarlar › Kaynak ekle).
  final VoidCallback? onAdd;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  /// Kaynak listesi değişince yeniden yüklenir.
  late Future<List<(UserSource, List<LiveChannel>)>> _loaded = _load();
  String? _category;

  Future<List<(UserSource, List<LiveChannel>)>> _load() async {
    try {
      return [for (final s in widget.sources.of(widget.kind)) (s, await widget.sources.channels(s))];
    } catch (e) {
      // Okunamayan liste sessiz boş sayfa bırakıyordu: günlüğe ve ekrana.
      Diagnostics.instance.log('liste', '${widget.kind.label} okunamadı: $e');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.sources.addListener(_reload);
  }

  @override
  void dispose() {
    widget.sources.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() => _loaded = _load());

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final padding = PageLayout.scrollPadding(context, metrics);
    final header = Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: AppHeader(
        clock: widget.clock,
        profileName: widget.profileName,
        onHome: widget.onHome,
        onMore: widget.onMore,
        onProfile: widget.onProfile,
      ),
    );
    final content = FutureBuilder(
      future: _loaded,
      builder: (context, snap) {
        final loaded = snap.data;
        final inset = EdgeInsets.fromLTRB(padding.left, phone ? 4 : 16, padding.right, phone ? padding.bottom : 0);
        if (snap.hasError) {
          return Padding(
            padding: inset,
            child: Text(
              '${widget.kind.label} listeleri okunamadı (${snap.error}).',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: RedoxRoles.error),
            ),
          );
        }
        if (loaded == null) {
          // Büyük liste ayrı iş parçacığında okunuyor.
          return Padding(
            padding: inset,
            child: Row(
              children: [
                const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 14),
                Text(
                  '${widget.kind.label} listeleri yükleniyor…',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        if (loaded.isEmpty) return Padding(padding: inset, child: _empty(context));
        if (widget.kind == SourceKind.film) {
          final all = _films(loaded);
          return _posterGrid<LiveChannel>(
            items: all,
            categoryOf: (c) => c.category,
            // Afişte temiz ad: "|MULTI| Ad (2023) [4K]" etiketleri kartı dolduruyordu.
            titleOf: (c) => switch (Tmdb.cleanName(c.name).$1) {
              '' => c.name,
              final name => name,
            },
            artworkOf: (c) => TmdbPoster(name: c.name, url: c.logoUrl, tmdb: widget.tmdb),
            onOpen: widget.onWatch == null ? null : (list, i) => _open(list, i),
            padding: padding,
            phone: phone,
          );
        }
        return _posterGrid<Series>(
          items: _catalog(loaded),
          categoryOf: (s) => s.category,
          titleOf: (s) => s.name,
          badgeOf: (s) => s.shortSummary,
          artworkOf: (s) => TmdbPoster(name: s.name, url: s.poster, tmdb: widget.tmdb, series: true),
          onOpen: (list, i) => unawaited(_openSeries(list[i])),
          padding: padding,
          phone: phone,
        );
      },
    );
    return Padding(
      // Telefonda başlık durum çubuğuna (saatin altına) yaslı.
      padding: EdgeInsets.only(
        top: phone ? MediaQuery.paddingOf(context).top : padding.top,
        bottom: phone ? 0 : padding.bottom,
      ),
      // Telefonda başlık aşağı kaydırınca gizlenir, yukarı kaydırınca geri
      // gelir (kullanıcı isteği); TV/tablette sabit.
      child: phone
          ? HidingHeader(header: header, child: content)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Expanded(child: content),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final label = widget.kind.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label kaynağı yok. Ayarlar › Kaynak ekle'de $label seçip bir liste ekleyin (M3U, Xtream, portal…).",
          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
        if (widget.onAdd != null) ...[
          const SizedBox(height: 16),
          GlassButton(label: 'Kaynak ekle', icon: RedoxIcons.add, onPressed: widget.onAdd),
        ],
      ],
    );
  }

  /// Izgara listesinin kategorilere ayrılmışı (liste değişince yeniden).
  Object? _groupedOf;
  Map<String, List<Object?>> _groups = const {};

  /// Afiş ızgarası (Film: filmler; Dizi: diziler) ve üstte kategori
  /// çipleri (birden çok kategori varsa).
  Widget _posterGrid<T>({
    required List<T> items,
    required String Function(T) categoryOf,
    required String Function(T) titleOf,
    String? Function(T)? badgeOf,
    required Widget Function(T) artworkOf,
    required void Function(List<T> list, int index)? onOpen,
    required EdgeInsets padding,
    required bool phone,
  }) {
    // Kategoriler ve sayıları liste başına bir kez (145 bin filmde her
    // yeniden çizimde baştan saymak Chromecast'i donduruyordu).
    if (!identical(items, _groupedOf)) {
      _groupedOf = items;
      final groups = <String, List<Object?>>{};
      for (final x in items) {
        groups.putIfAbsent(categoryOf(x), () => []).add(x);
      }
      _groups = groups;
    }
    final groups = _groups;
    final categories = groups.keys.toList();
    final list = _category == null ? items : [...?groups[_category]?.cast<T>()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.length > 1)
          Padding(
            padding: EdgeInsets.only(left: padding.left - 12),
            child: ScrollHintRow(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
              child: Row(
                children: [
                  for (final (i, (c, label, count)) in [
                    (null, 'Tümü', items.length),
                    for (final c in categories) (c, c, groups[c]!.length),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    CategoryChip(
                      label: label,
                      count: count,
                      selected: c == _category,
                      onPressed: () => setState(() => _category = c),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            // Üstte/altta odak payı: büyüyen (1.08) afiş ve halkası ilk ve
            // son satırda ızgaranın kenarında kesilmesin.
            padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, phone ? padding.bottom : 24),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: phone ? 130 : 150,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2 / 3,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final x = list[i];
              // D-pad odağında afiş ortalanır: kenara yaslanınca büyüyen kart
              // ızgaranın altında/üstünde kesiliyordu (TV'de görüldü).
              return LayoutBuilder(
                builder: (context, box) => CenterOnFocus(
                  child: MediaCard(
                    title: titleOf(x),
                    badge: switch (badgeOf?.call(x)) {
                      final text? => _Badge(text),
                      null => null,
                    },
                    width: box.maxWidth,
                    focused: null,
                    artwork: artworkOf(x),
                    onPressed: onOpen == null ? null : () => onOpen(list, i),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Film: TMDB varsa önce ayrıntı sayfası (İzle ile oynar), yoksa doğrudan
  /// oynar.
  void _open(List<LiveChannel> list, int i) {
    final tmdb = widget.tmdb;
    if (tmdb == null) return unawaited(widget.onWatch!(list, i));
    unawaited(Navigator.of(context).push(_detail(tmdb, list, i)));
  }

  /// Film sayfası; "Benzerleri" bütün filmlerde aranır (kategori süzgecinden
  /// bağımsız), seçilen film aynı sayfanın yerine açılır (Geri listeye döner).
  Route<void> _detail(Tmdb tmdb, List<LiveChannel> list, int i) => FilmDetailPage.route(
    film: list[i],
    tmdb: tmdb,
    onWatch: () => unawaited(widget.onWatch!(list, i)),
    library: _allFilms,
    onSimilar: (c) => unawaited(Navigator.of(context).pushReplacement(_detail(tmdb, _allFilms, _allFilms.indexOf(c)))),
  );

  /// Film listelerinin kayıtları tek listede; yüklenen liste değişmedikçe
  /// aynı nesne (ızgaranın kategori önbelleği ona bağlı).
  List<LiveChannel> _films(List<(UserSource, List<LiveChannel>)> loaded) {
    if (!identical(loaded, _filmsOf)) {
      _filmsOf = loaded;
      _allFilms = loaded.length == 1 ? loaded.single.$2 : [for (final (_, l) in loaded) ...l];
    }
    return _allFilms;
  }

  Object? _filmsOf;
  List<LiveChannel> _allFilms = const [];

  /// Dizi listelerinin dizileri; yüklenen liste değişmedikçe yeniden
  /// kurulmaz (büyük listelerde on binlerce bölüm).
  List<Series> _catalog(List<(UserSource, List<LiveChannel>)> loaded) {
    if (!identical(loaded, _catalogOf)) {
      _catalogOf = loaded;
      _series = SeriesCatalog.build([for (final (s, l) in loaded) (s.id, l)]);
    }
    return _series;
  }

  Object? _catalogOf;
  List<Series> _series = const [];

  /// Dizi sayfası; dizi kilitliyse önce PIN.
  Future<void> _openSeries(Series series) async {
    final gate = LockScope.maybeOf(context);
    final key = SeriesDetailPage.lockKey(series);
    final source = ContentLocks.folder(series.sourceId, const []);
    for (final k in [source, key]) {
      if (gate != null && gate.locks.blocks(k) && !await gate.pass(context, k)) return;
    }
    if (!mounted) return;
    final page = SeriesDetailPage(
      series: series,
      tmdb: widget.tmdb,
      favorites: widget.favorites,
      onWatch: widget.onWatch,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Yeni rota kabuğun altında değil: kilit kapsamı taşınır.
        builder: (_) => gate == null ? page : LockScope(locks: gate.locks, profiles: gate.profiles, child: page),
      ),
    );
  }
}

/// Afişin köşesinde koyu hap ("2 sezon · 3 bölüm").
class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xD90B0B20), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w700),
    ),
  );
}
