import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/double_back_to_exit.dart';
import '../../../core/content/channel_folder.dart';
import '../../../core/content/content_locks.dart';
import '../../../core/content/favorites.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';
import '../../locks/lock_scope.dart';
import '../../radio/widgets/station_avatar.dart';

/// Kanal ağacında gezinme (Kaynaklar'ın içi, Dizi sayfası). **Klasör
/// görünümü:** açık klasörün alt klasörleri, sonra kayıtları; OK klasöre
/// girer, "Yukarı" ve Geri üst klasöre çıkar. **Liste görünümü** ([folders]
/// false): [flat] düz liste. OK oynatır (klasör görünümünde klasörün
/// kayıtlarıyla); yıldız Favoriler › Kaynaklar'a ekler; kilit düğmeleri
/// klasör ve kayıtta (LockScope varsa).
class ChannelBrowser extends StatefulWidget {
  const ChannelBrowser({
    super.key,
    required this.root,
    required this.flat,
    required this.title,
    this.folders = true,
    this.folderLock,
    this.onWatch,
    this.favorites,
  });

  final ChannelFolder root;
  final List<LiveChannel> flat;

  /// Klasör yolunun başı ("Yukarı" satırında: "Başlık › A › B").
  final String title;
  final bool folders;

  /// Klasörün kilit anahtarı (kökten yol); null ise klasörlerde kilit yok.
  final String Function(List<String> path)? folderLock;
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  /// Yıldız (Favoriler › Kaynaklar); null ise yıldız yok.
  final Favorites? favorites;

  @override
  State<ChannelBrowser> createState() => _ChannelBrowserState();
}

class _ChannelBrowserState extends State<ChannelBrowser> {
  /// Açık klasörün yolu (kökten adlar).
  final List<String> _path = [];

  void _up() => setState(() => _path.removeLast());

  /// Alt klasöre girer; kendisi ya da bir üstü kilitliyse PIN sorar.
  Future<void> _enter(String name) async {
    final gate = LockScope.maybeOf(context);
    final lockOf = widget.folderLock;
    if (gate != null && lockOf != null) {
      final path = [..._path, name];
      for (var n = 1; n <= path.length; n++) {
        final key = lockOf(path.sublist(0, n));
        if (gate.locks.blocks(key) && !await gate.pass(context, key)) return;
        if (!mounted) return;
      }
    }
    if (mounted) setState(() => _path.add(name));
  }

  @override
  Widget build(BuildContext context) {
    // Geri: alt klasördeyse üst klasöre çıkar; kökte sayfaya bırakır.
    return BackInterceptor(
      active: widget.folders && _path.isNotEmpty,
      onBack: _up,
      child: ListenableBuilder(
        listenable: widget.favorites ?? const _Never(),
        builder: (context, _) => widget.folders ? _folderView(context) : _listView(widget.flat),
      ),
    );
  }

  /// Düz liste: [items] satırları; OK [items] listesiyle oynatır.
  /// [prefix]: listenin başındaki satırlar (klasörler, "Yukarı").
  Widget _listView(List<LiveChannel> items, {List<Widget> prefix = const []}) {
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
            lockKey: ContentLocks.item(c.streams.first),
            onPressed: widget.onWatch == null ? null : () => unawaited(widget.onWatch!(items, i - prefix.length)),
          ),
        );
      },
    );
  }

  /// Klasör görünümü: açık klasörün alt klasörleri, sonra kayıtları.
  Widget _folderView(BuildContext context) {
    final tree = widget.root;
    final folder = tree.at(_path) ?? tree;
    final t = Theme.of(context).textTheme;
    final prefix = <Widget>[
      if (_path.isNotEmpty)
        _FolderRow(
          name: 'Yukarı',
          detail: [widget.title, ..._path].join(' › '),
          up: true,
          autofocus: true,
          onPressed: _up,
        ),
      for (final (i, f) in folder.folders.indexed)
        _FolderRow(
          name: f.name,
          detail: '${f.total} kayıt',
          autofocus: _path.isEmpty && i == 0,
          lockKey: widget.folderLock?.call([..._path, f.name]),
          onPressed: () => unawaited(_enter(f.name)),
        ),
    ];
    if (prefix.isEmpty && folder.items.isEmpty) {
      return Text('Bu klasör boş.', style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant));
    }
    return _listView(folder.items, prefix: prefix);
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
    this.lockKey,
  });

  final String name;
  final String detail;
  final VoidCallback onPressed;
  final bool up;
  final bool autofocus;

  /// Klasörün kilit anahtarı; null ise kilit düğmesi yok ("Yukarı").
  final String? lockKey;

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
    return _withLock(context, row, lockKey);
  }
}

/// Satırın sağına kilit düğmesi (kilit kapsamı ve anahtar varsa).
Widget _withLock(BuildContext context, Widget row, String? lockKey, {List<Widget> before = const []}) {
  final lockable = lockKey != null && LockScope.maybeOf(context)?.profiles != null;
  if (!lockable && before.isEmpty) return row;
  return Row(
    children: [
      Expanded(child: row),
      ...before,
      if (lockable) ...[const SizedBox(width: 8), LockButton(lockKey: lockKey)],
    ],
  );
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    this.onPressed,
    this.autofocus = false,
    this.favorite,
    this.onFavorite,
    this.lockKey,
  });

  /// Kaydın kilit anahtarı; null ise kilit düğmesi yok.
  final String? lockKey;

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
    return _withLock(
      context,
      row,
      lockKey,
      before: [
        if (fav != null) ...[const SizedBox(width: 8), StarButton(favorite: fav, onPressed: onFavorite)],
      ],
    );
  }
}

/// Favori yıldızı: favorideyse dolu altın; kumandada odak halkası ve amber
/// zemin (dizi bölümleri de kullanır).
class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.favorite, this.onPressed});

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
