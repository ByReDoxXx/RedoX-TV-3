import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/channel_folder.dart';
import '../../core/content/content_locks.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/media_card.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../sources/widgets/channel_browser.dart';
import 'film_detail_page.dart';
import 'widgets/series_header.dart';
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

  Future<List<(UserSource, List<LiveChannel>)>> _load() async => [
    for (final s in widget.sources.of(widget.kind)) (s, await widget.sources.channels(s)),
  ];

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
        if (loaded == null) return const SizedBox.shrink();
        final inset = EdgeInsets.fromLTRB(padding.left, phone ? 4 : 16, padding.right, phone ? padding.bottom : 0);
        if (loaded.isEmpty) return Padding(padding: inset, child: _empty(context));
        return widget.kind == SourceKind.film
            ? _films(context, [for (final (_, l) in loaded) ...l], padding, phone)
            : Padding(padding: inset, child: _series(loaded));
      },
    );
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: phone ? 0 : padding.bottom),
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

  /// Film: kategori çipleri ve afiş ızgarası.
  Widget _films(BuildContext context, List<LiveChannel> all, EdgeInsets padding, bool phone) {
    final categories = {for (final c in all) c.category}.toList();
    final list = _category == null
        ? all
        : [
            for (final c in all)
              if (c.category == _category) c,
          ];
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
                    (null, 'Tümü', all.length),
                    for (final c in categories) (c, c, all.where((x) => x.category == c).length),
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
            padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, phone ? padding.bottom : 16),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: phone ? 130 : 150,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2 / 3,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              final poster = c.logoUrl;
              return LayoutBuilder(
                builder: (context, box) => MediaCard(
                  title: c.name,
                  width: box.maxWidth,
                  focused: null,
                  artwork: TmdbPoster(name: c.name, url: poster, tmdb: widget.tmdb),
                  onPressed: widget.onWatch == null ? null : () => _open(list, i),
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
    unawaited(
      Navigator.of(context)
          .push(FilmDetailPage.route(film: list[i], tmdb: tmdb, onWatch: () => unawaited(widget.onWatch!(list, i)))),
    );
  }

  /// Dizi: dizi › sezon › bölüm klasörleri; birden çok kaynakta kaynak
  /// klasörleri en üstte.
  Widget _series(List<(UserSource, List<LiveChannel>)> loaded) {
    final ChannelFolder root;
    final String Function(List<String>) lock;
    if (loaded.length == 1) {
      final (s, list) = loaded.single;
      root = ChannelFolder.build(list, episodes: true);
      lock = (path) => ContentLocks.folder(s.id, path);
    } else {
      root = ChannelFolder('');
      final ids = <String, String>{};
      for (final (s, list) in loaded) {
        final tree = ChannelFolder.build(list, episodes: true);
        root.folders.add(ChannelFolder(s.name, folders: tree.folders, items: tree.items));
        ids[s.name] = s.id;
      }
      lock = (path) => ContentLocks.folder(ids[path.first] ?? path.first, path.sublist(1));
    }
    return ChannelBrowser(
      key: ObjectKey(loaded),
      root: root,
      flat: [for (final (_, l) in loaded) ...l],
      title: widget.kind.label,
      folderLock: lock,
      onWatch: widget.onWatch,
      favorites: widget.favorites,
      header: widget.tmdb == null ? null : (path) => _seriesHeader(path, sourceFolders: loaded.length > 1),
    );
  }

  /// Dizi klasörüne girilince TMDB özeti (afiş, ad, yıl, puan, özet).
  Widget? _seriesHeader(List<String> path, {required bool sourceFolders}) {
    final depth = sourceFolders ? 2 : 1;
    if (path.length < depth) return null;
    final name = path[depth - 1];
    return SeriesHeader(name: name, tmdb: widget.tmdb!);
  }
}
