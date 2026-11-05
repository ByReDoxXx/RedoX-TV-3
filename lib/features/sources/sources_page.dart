import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/mouse_mode.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/search_box.dart';
import '../locks/lock_scope.dart';
import '../search/search_page.dart';
import 'source_channels_page.dart';
import 'source_search.dart';
import 'widgets/source_widgets.dart';

/// Kaynaklar: kullanıcının eklediği listeler (eski "Özel M3U"). Üstte başlık,
/// toplam ve "Kaynak ekle" (Ayarlar › Kaynak ekle), altında arama ve türe göre
/// süzme. Listeler türlerine göre gruplanır; her liste bir klasördür, içine
/// girince kayıtları, OK tam ekran.
///
/// **Arama:** liste adlarında ve listelerin içindeki kayıtlarda (kanal, film,
/// bölüm) yapılır; bulunan kayıt doğrudan oynar. Kilitli listelerin içi aranmaz.
class SourcesPage extends StatefulWidget {
  const SourcesPage({
    super.key,
    required this.sources,
    this.favorites,
    required this.clock,
    required this.profileName,
    this.onWatch,
    this.onAdd,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final UserSources sources;

  /// Kaynaktaki kayıtlarda yıldız (Favoriler).
  final Favorites? favorites;

  /// Klasördeki kanalı tam ekran açar.
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  /// Ayarlar > Kaynak ekle sekmesini açar.
  final VoidCallback? onAdd;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  /// Süzgeç; null: Tümü.
  SourceKind? _kind;
  String _query = '';

  late final _search = SourceSearch(widget.sources);
  List<SourceHit> _hits = const [];
  bool _searching = false;

  /// Her aramada artar: geç biten eski arama sonucu yazmaz.
  int _run = 0;
  Timer? _debounce;

  /// Yazarken her harfte taranmasın.
  static const _debounceTime = Duration(milliseconds: 250);

  UserSources get _sources => widget.sources;

  @override
  void initState() {
    super.initState();
    _sources.addListener(_onSources);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _run++;
    _sources.removeListener(_onSources);
    super.dispose();
  }

  void _onSources() {
    _search.reset();
    if (_query.isNotEmpty) _schedule(Duration.zero);
  }

  void _setQuery(String q) {
    setState(() {
      _query = q;
      if (q.trim().isEmpty) {
        _run++;
        _debounce?.cancel();
        _hits = const [];
        _searching = false;
      } else {
        _searching = true;
      }
    });
    if (q.trim().isNotEmpty) _schedule(_debounceTime);
  }

  void _setKind(SourceKind? kind) {
    setState(() => _kind = kind);
    if (_query.trim().isNotEmpty) _schedule(Duration.zero);
  }

  void _schedule(Duration wait) {
    _debounce?.cancel();
    _debounce = Timer(wait, () => unawaited(_scan()));
  }

  Future<void> _scan() async {
    final run = ++_run;
    final hits = await _search.run(
      _query,
      kind: _kind,
      locks: LockScope.maybeOf(context)?.locks,
      cancelled: () => run != _run,
    );
    if (!mounted || run != _run) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final phone = metrics.formFactor == FormFactor.phone;
    return ListenableBuilder(
      listenable: _sources,
      builder: (context, _) {
        final header = AppHeader(
          clock: widget.clock,
          profileName: widget.profileName,
          onHome: widget.onHome,
          onMore: widget.onMore,
          onProfile: widget.onProfile,
        );
        final body = _body(context, phone);
        // Telefonda başlık üstte; aşağı kaydırınca gizlenir, yukarı kaydırınca
        // geri gelir (kullanıcı isteği). TV/tablette içerikle kayar.
        if (phone) {
          return Padding(
            // Telefonda başlık durum çubuğuna (saatin altına) yaslı (kullanıcı isteği).
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: HidingHeader(
              header: Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: header,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding.left, 6, padding.right, 16),
                child: body,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, const SizedBox(height: 18), body],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, bool phone) {
    // Bütün listeler (Canlı TV, Film, Dizi): Film ve Dizi listeleri kendi
    // bölümlerinde de görünür; burada silinince oradan da kalkar.
    final all = [for (final k in SourceKind.values) ..._sources.of(k)];
    final kinds = [
      for (final k in SourceKind.values)
        if (_sources.of(k).isNotEmpty) k,
    ];
    // Süzülen tür kalmadıysa (silindi) Tümü.
    final kind = kinds.contains(_kind) ? _kind : null;
    final searching = _query.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, all.length),
        if (all.isEmpty) ...[
          const SizedBox(height: 20),
          _EmptySources(onAdd: widget.onAdd),
        ] else ...[
          const SizedBox(height: 14),
          _filters(context, all.length, kinds, kind),
          const SizedBox(height: 18),
          if (searching) _results(context, phone, kind) else _lists(phone, kinds, kind),
        ],
      ],
    );
  }

  Widget _title(BuildContext context, int lists) {
    final t = Theme.of(context).textTheme;
    final add = widget.onAdd;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kaynaklar', style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
              if (lists > 0)
                Text(
                  '$lists liste · ${_sources.channelCount} kayıt',
                  style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
            ],
          ),
        ),
        // Boşken düğme yönergenin altındadır.
        if (add != null && lists > 0) PrimaryButton(label: 'Kaynak ekle', icon: RedoxIcons.add, onPressed: add),
      ],
    );
  }

  /// Arama ve tür çipleri. TV'de arama düğmesi çiplerle aynı sırada; dokunmatikte
  /// arama kutusu kendi satırında (telefon) ya da çiplerin yanında.
  Widget _filters(BuildContext context, int total, List<SourceKind> kinds, SourceKind? kind) {
    final box = SearchBox(query: _query, hint: 'Kaynaklarda ara', onChanged: _setQuery);
    final chips = kinds.length < 2
        ? null
        : Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              CategoryChip(label: 'Tümü', count: total, selected: kind == null, onPressed: () => _setKind(null)),
              for (final k in kinds)
                CategoryChip(
                  label: k.label,
                  count: _sources.of(k).length,
                  selected: kind == k,
                  onPressed: () => _setKind(k),
                ),
            ],
          );
    if (usesSystemTextInput(context)) {
      return Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [box, ?chips]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: box),
        if (chips != null) ...[const SizedBox(height: 10), chips],
      ],
    );
  }

  /// Listeler: Tümü'nde türlere göre gruplu.
  Widget _lists(bool phone, List<SourceKind> kinds, SourceKind? kind) {
    Widget grid(List<UserSource> items, {bool first = false}) =>
        _grid(phone, [for (final (i, s) in items.indexed) _card(s, autofocus: first && i == 0)]);
    if (kind != null || kinds.length < 2) return grid(_sources.of(kind ?? kinds.single), first: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, k) in kinds.indexed) ...[
          if (i > 0) const SizedBox(height: 20),
          SectionTitle(title: k.label),
          const SizedBox(height: 10),
          grid(_sources.of(k), first: i == 0),
        ],
      ],
    );
  }

  Widget _grid(bool phone, List<Widget> children) =>
      TileGrid(columns: phone ? 1 : 3, minWidth: phone ? 0 : 230, children: children);

  Widget _card(UserSource s, {bool autofocus = false}) => FolderCard(
    source: s,
    autofocus: autofocus,
    locked: LockScope.maybeOf(context)?.locks.folderLock(s.id, const []) != null,
    onPressed: () => unawaited(_open(context, s)),
  );

  /// Arama sonuçları: eşleşen listeler ve listelerin içindeki kayıtlar.
  Widget _results(BuildContext context, bool phone, SourceKind? kind) {
    final t = Theme.of(context).textTheme;
    final q = SearchPage.fold(_query.trim());
    final lists = [
      for (final s in kind == null ? _sources.items : _sources.of(kind))
        if (SearchPage.fold(s.name).contains(q)) s,
    ];
    final hint = t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant);
    if (lists.isEmpty && _hits.isEmpty) {
      if (_searching) return Text('Aranıyor…', style: hint);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"${_query.trim()}" için sonuç yok', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
          const SizedBox(height: 4),
          Text('Liste adlarında ve listelerin içinde arandı; kilitli listelerin içi aranmaz.', style: hint),
          const SizedBox(height: 12),
          GlassButton(label: 'Aramayı temizle', icon: RedoxIcons.close, onPressed: () => _setQuery('')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lists.isNotEmpty) ...[
          SectionTitle(
            title: 'Listeler',
            trailing: Text('${lists.length}', style: hint),
          ),
          const SizedBox(height: 10),
          _grid(phone, [for (final s in lists) _card(s)]),
          const SizedBox(height: 20),
        ],
        if (_searching && _hits.isEmpty)
          Text('Listelerin içinde aranıyor…', style: hint)
        else if (_hits.isNotEmpty) ...[
          SectionTitle(
            title: 'Listelerin içinde',
            trailing: Text(
              _hits.length >= SourceSearch.limit ? 'İlk ${SourceSearch.limit}' : '${_hits.length}',
              style: hint,
            ),
          ),
          const SizedBox(height: 10),
          TileGrid(
            columns: phone ? 1 : 2,
            minWidth: phone ? 0 : 300,
            children: [
              for (final h in _hits)
                SourceHitRow(
                  name: h.channel.name,
                  detail: [h.source.name, if (h.channel.category.isNotEmpty) h.channel.category].join(' · '),
                  source: h.source,
                  onPressed: widget.onWatch == null ? null : () => unawaited(widget.onWatch!(h.list, h.index)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Kilitli kaynak PIN ister.
  Future<void> _open(BuildContext context, UserSource s) async {
    final gate = LockScope.maybeOf(context);
    if (gate?.locks.folderLock(s.id, const []) case final key?) {
      if (!await gate!.pass(context, key)) return;
    }
    if (!context.mounted) return;
    final page = SourceChannelsPage(sources: _sources, source: s, onWatch: widget.onWatch, favorites: widget.favorites);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Yeni rota kabuğun altında değil: kilit kapsamı taşınır.
        builder: (_) => gate == null ? page : LockScope(locks: gate.locks, profiles: gate.profiles, child: page),
      ),
    );
  }
}

/// Henüz liste yok: ne eklenebileceği ve ekleme düğmesi.
class _EmptySources extends StatelessWidget {
  const _EmptySources({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final add = onAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconTile(icon: RedoxIcons.folder, tint: RedoxSeeds.gold, size: 64),
        const SizedBox(height: 14),
        Text('Henüz liste yok', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            "Ayarlar > Kaynak ekle'den M3U, JSON, HTML, Xtream, portal, dosya, USB/SSD klasörü ya da telefonla "
            'ekleyin; her liste burada bir klasör olur.',
            style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
        ),
        if (add != null) ...[
          const SizedBox(height: 16),
          PrimaryButton(label: 'Kaynak ekle', icon: RedoxIcons.add, autofocus: true, onPressed: add),
        ],
      ],
    );
  }
}
