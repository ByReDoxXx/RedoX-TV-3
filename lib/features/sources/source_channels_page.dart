import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/channel_folder.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/theme/redox_type.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/segmented_toggle.dart';
import '../radio/widgets/station_avatar.dart';

/// Kaynağın içi: iki görünüm (kullanıcı isteği). **Klasör:** kanallar grup
/// adı ve adlarındaki "/" ile iç içe klasörlerdedir (ChannelFolder); OK
/// klasöre girer, "Yukarı" ve Geri üst klasöre çıkar. **Liste:** bütün
/// kanallar düz liste. OK tam ekran (klasör görünümünde klasörün kayıtlarıyla);
/// yıldız Favoriler › Kaynaklar'a ekler. Üstte Yenile (adresle eklendiyse) ve
/// Sil.
class SourceChannelsPage extends StatefulWidget {
  const SourceChannelsPage({super.key, required this.sources, required this.source, this.onWatch, this.favorites});

  final UserSources sources;
  final UserSource source;
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  /// Yıldız (Favoriler › Kaynaklar); null ise yıldız yok.
  final Favorites? favorites;

  @override
  State<SourceChannelsPage> createState() => _SourceChannelsPageState();
}

class _SourceChannelsPageState extends State<SourceChannelsPage> {
  late UserSource _source = widget.source;
  late Future<List<LiveChannel>> _channels = widget.sources.channels(_source);
  bool _busy = false;

  /// Klasör görünümü (varsayılan); false: düz liste.
  bool _folders = true;

  /// Klasör görünümünde açık klasörün yolu (kökten adlar).
  final List<String> _path = [];

  /// Kanallardan kurulan ağaç (liste değişince yeniden).
  List<LiveChannel>? _treeOf;
  ChannelFolder _tree = ChannelFolder('');

  ChannelFolder _treeFor(List<LiveChannel> list) {
    if (!identical(list, _treeOf)) {
      _treeOf = list;
      _tree = ChannelFolder.build(list);
    }
    return _tree;
  }

  void _up() => setState(() => _path.removeLast());

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final s = await widget.sources.refresh(_source);
      setState(() {
        _source = s;
        _channels = widget.sources.channels(s);
        _path.clear();
      });
      _toast('Liste yenilendi: ${s.count} kanal.');
    } on SourceException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: Text('"${_source.name}" silinsin mi?'),
        content: const Text('Liste ve kanalları bu cihazdan kaldırılır.'),
        actions: [
          GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context, false)),
          PrimaryButton(label: 'Sil', icon: RedoxIcons.close, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );
    if (ok != true) return;
    await widget.sources.remove(_source);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final pad = phone ? 16.0 : 40.0;
    // Geri: alt klasördeyse üst klasöre çıkar; kökte sayfayı kapatır.
    return PopScope(
      canPop: !_folders || _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _path.isNotEmpty) _up();
      },
      child: Scaffold(
        backgroundColor: RedoxSeeds.obsidian,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const RedoxIcon(RedoxIcons.folder, color: RedoxSeeds.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface),
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: RedoxSeeds.amber),
                        ),
                      ),
                    if (_source.refreshable)
                      GlassButton(
                        label: 'Yenile',
                        icon: RedoxIcons.sync,
                        iconOnly: phone,
                        onPressed: _busy ? null : _refresh,
                      ),
                    const SizedBox(width: 10),
                    GlassButton(label: 'Sil', icon: RedoxIcons.close, iconOnly: phone, onPressed: _delete),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_source.count} kanal · ${_source.origin.label}${_source.url == null ? '' : ' · ${_source.url}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SegmentedToggle(
                  segments: const [
                    ToggleSegment('Klasör görünümü', RedoxIcons.folder),
                    ToggleSegment('Liste görünümü', RedoxIcons.menu),
                  ],
                  selectedIndex: _folders ? 0 : 1,
                  onChanged: (i) => setState(() => _folders = i == 0),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder(
                    future: _channels,
                    builder: (context, snap) {
                      final list = snap.data;
                      if (list == null) return const SizedBox.shrink();
                      return ListenableBuilder(
                        listenable: widget.favorites ?? const _Never(),
                        builder: (context, _) => _folders ? _folderView(context, list) : _listView(list, list),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Düz liste: [items] satırları; OK [items] listesiyle oynatır.
  /// [prefix]: listenin başındaki satırlar (klasörler, "Yukarı").
  Widget _listView(List<LiveChannel> all, List<LiveChannel> items, {List<Widget> prefix = const []}) {
    final fav = widget.favorites;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemExtent: 64,
      itemCount: prefix.length + items.length,
      itemBuilder: (context, i) {
        if (i < prefix.length) return Padding(padding: const EdgeInsets.only(bottom: 6), child: prefix[i]);
        final c = items[i - prefix.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _ChannelRow(
            channel: c,
            autofocus: i == 0,
            favorite: fav?.hasSource(c.streams.first),
            onFavorite: fav == null ? null : () => fav.toggleSource(FavoriteItem.of(c)),
            onPressed: widget.onWatch == null ? null : () => unawaited(widget.onWatch!(items, i - prefix.length)),
          ),
        );
      },
    );
  }

  /// Klasör görünümü: açık klasörün alt klasörleri, sonra kayıtları.
  Widget _folderView(BuildContext context, List<LiveChannel> all) {
    final tree = _treeFor(all);
    final folder = tree.at(_path) ?? tree;
    final t = Theme.of(context).textTheme;
    final prefix = <Widget>[
      if (_path.isNotEmpty)
        _FolderRow(
          name: 'Yukarı',
          detail: [_source.name, ..._path].join(' › '),
          up: true,
          autofocus: true,
          onPressed: _up,
        ),
      for (final (i, f) in folder.folders.indexed)
        _FolderRow(
          name: f.name,
          detail: '${f.total} kayıt',
          autofocus: _path.isEmpty && i == 0,
          onPressed: () => setState(() => _path.add(f.name)),
        ),
    ];
    if (prefix.isEmpty && folder.items.isEmpty) {
      return Text('Bu klasör boş.', style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant));
    }
    return _listView(all, folder.items, prefix: prefix);
  }
}

/// Favoriler verilmediğinde dinlenecek boş Listenable.
class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Klasör satırı (ya da "Yukarı").
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.name,
    required this.detail,
    required this.onPressed,
    this.up = false,
    this.autofocus = false,
  });

  final String name;
  final String detail;
  final VoidCallback onPressed;
  final bool up;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 48),
                RedoxIcon(up ? RedoxIcons.expandLess : RedoxIcons.folder, color: RedoxSeeds.gold, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, this.onPressed, this.autofocus = false, this.favorite, this.onFavorite});

  final LiveChannel channel;
  final VoidCallback? onPressed;
  final bool autofocus;

  /// Favoride mi; null ise yıldız yok.
  final bool? favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final row = FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${c.number}',
                    textAlign: TextAlign.right,
                    style: t.labelLarge!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
                  ),
                ),
                const SizedBox(width: 12),
                StationAvatar(station: c, size: 40, radius: RedoxRadius.sm),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [c.category, if (c.streams.length > 1) '${c.streams.length} akış'].join(' · '),
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final fav = favorite;
    if (fav == null) return row;
    return Row(
      children: [
        Expanded(child: row),
        const SizedBox(width: 8),
        _StarButton(favorite: fav, onPressed: onFavorite),
      ],
    );
  }
}

/// Favori yıldızı: favorideyse dolu altın.
class _StarButton extends StatelessWidget {
  const _StarButton({required this.favorite, this.onPressed});

  final bool favorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Semantics(
      button: true,
      label: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
      excludeSemantics: true,
      child: FocusGlow(
        borderRadius: BorderRadius.circular(size / 2),
        builder: (context, active) => Material(
          color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
          shape: CircleBorder(side: active ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder)),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: RedoxIcon(
                  RedoxIcons.star,
                  filled: favorite,
                  color: active ? RedoxSeeds.obsidian : (favorite ? RedoxSeeds.gold : RedoxRoles.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
