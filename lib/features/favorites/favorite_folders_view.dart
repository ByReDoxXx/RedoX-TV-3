import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/favorite_folders.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/channel_logo.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../sources/widgets/source_form_dialog.dart';

/// Favoriler › Klasörler: iç içe klasörler (kullanıcı isteği: "Dizi
/// İsmi/1.Sezon/Bölüm01"). Üstte yol ve düğmeler (Yukarı, Klasör ekle,
/// Listeden aktar); altta önce alt klasörler, sonra kayıtlar. Kayda
/// OK/dokunma klasörün kayıtlarını oynatıcıda açar (aynı klasörde ◄ ► ile
/// sonraki bölüm). Aktarım: adres (M3U, JSON, HTML) ya da Kaynaklar'daki bir
/// liste; grup ve ad yolları alt klasör olur (FavoriteFolder.import).
class FavoriteFoldersView extends StatefulWidget {
  const FavoriteFoldersView({
    super.key,
    required this.favorites,
    required this.padding,
    this.sources,
    this.onWatch,
    this.compact = false,
  });

  final Favorites favorites;
  final UserSources? sources;

  /// Klasörün kayıtları ve açılan kaydın sırası.
  final void Function(List<LiveChannel> list, int index)? onWatch;
  final EdgeInsets padding;
  final bool compact;

  static const rowHeight = 64.0;

  @override
  State<FavoriteFoldersView> createState() => _FavoriteFoldersViewState();
}

class _FavoriteFoldersViewState extends State<FavoriteFoldersView> {
  final List<String> _path = [];
  bool _busy = false;

  Favorites get _fav => widget.favorites;

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addFolder() async {
    final r = await showSourceForm(
      context,
      title: 'Klasör ekle',
      description: _path.isEmpty ? 'Klasörler altında yeni klasör.' : '"${_path.last}" içinde yeni klasör.',
      fields: const [FormFieldSpec('name', 'Ad', hint: 'Örn. Dizi adı')],
    );
    final name = r?['name'];
    if (name == null || name.isEmpty) return;
    _fav.addFolder(_path, name);
  }

  Future<void> _import() async {
    final sources = widget.sources;
    final lists = sources?.items ?? const <UserSource>[];
    // Kaynak seçimi: adres ya da Kaynaklar'daki listeler.
    final choice = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: const Text('Listeden aktar'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'adres'),
            child: const Text('Adres ile (M3U, JSON, HTML)'),
          ),
          for (final s in lists)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, s), child: Text('${s.name} · ${s.count} kanal')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    Future<List<LiveChannel>> load;
    if (choice is UserSource) {
      load = sources!.channels(choice);
    } else {
      final r = await showSourceForm(
        context,
        title: 'Adres ile aktar',
        description:
            'Listedeki grup ve ad yolları ("Dizi İsmi/1.Sezon" › "Bölüm01") alt klasör olur. '
            'Liste Kaynaklar\'a eklenmez.',
        fields: const [FormFieldSpec('url', 'Adres', kind: FieldKind.url, hint: 'https://…')],
      );
      final url = r?['url'];
      if (url == null || sources == null) return;
      load = sources.fetch(url);
    }
    setState(() => _busy = true);
    try {
      final added = _fav.importChannels(_path, await load);
      _toast(added == 0 ? 'Yeni kayıt yok.' : '$added kayıt eklendi.');
    } on SourceException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFolder(FavoriteFolder f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: Text('"${f.name}" silinsin mi?'),
        content: Text('İçindeki ${f.total} kayıt ve alt klasörler de silinir.'),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok ?? false) _fav.removeFolder([..._path, f.name]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: _fav,
      builder: (context, _) {
        // Açık klasör silindiyse köke dön.
        var folder = _fav.folderAt(_path);
        if (folder == null) {
          _path.clear();
          folder = _fav.folders;
        }
        final current = folder;
        final rows = [
          for (final f in current.folders)
            _Row(
              leading: const _FolderIcon(),
              title: f.name,
              subtitle: '${f.folders.length} klasör · ${f.total} kayıt',
              onPressed: () => setState(() => _path.add(f.name)),
              onRemove: () => unawaited(_removeFolder(f)),
              removeLabel: 'Klasörü sil',
            ),
          for (final (i, item) in current.items.indexed)
            _Row(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(RedoxRadius.sm),
                child: SizedBox.square(
                  dimension: 44,
                  child: ChannelLogo(name: item.name, logoUrl: item.logo, size: 1, alignment: Alignment.center),
                ),
              ),
              title: item.name,
              subtitle: current.name.isEmpty ? 'Klasörler' : current.name,
              onPressed: () => widget.onWatch?.call(current.channels, i),
              onRemove: () => _fav.removeItem(_path, item),
              removeLabel: 'Kaydı sil',
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.padding.left, 6, widget.padding.right, 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_path.isNotEmpty)
                    GlassButton(
                      label: 'Yukarı',
                      icon: RedoxIcons.chevronLeft,
                      onPressed: () => setState(() => _path.removeLast()),
                    ),
                  Text(
                    ['Klasörler', ..._path].join(' › '),
                    style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                  ),
                  GlassButton(label: 'Klasör ekle', icon: RedoxIcons.add, onPressed: _addFolder),
                  if (widget.sources != null)
                    GlassButton(
                      label: 'Listeden aktar',
                      icon: RedoxIcons.bulkAdd,
                      onPressed: _busy ? null : () => unawaited(_import()),
                    ),
                  if (_busy)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: RedoxSeeds.amber),
                    ),
                ],
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(widget.padding.left, 8, widget.padding.right, 0),
                      child: Text(
                        _path.isEmpty
                            ? 'Klasör yok. "Klasör ekle" ile oluşturun ya da "Listeden aktar" ile bir listedeki '
                                  'dizileri klasörlere yerleştirin (ör. Dizi İsmi › 1.Sezon › Bölüm01).'
                            : 'Bu klasör boş.',
                        style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(widget.padding.left, 0, widget.padding.right, widget.padding.bottom),
                      itemExtent: FavoriteFoldersView.rowHeight + 8,
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: rows[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FolderIcon extends StatelessWidget {
  const _FolderIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: RedoxSeeds.amber.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(RedoxRadius.sm),
    ),
    child: const Center(child: RedoxIcon(RedoxIcons.folder, color: RedoxSeeds.amber)),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    required this.onRemove,
    required this.removeLabel,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return Container(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: radius,
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusGlow(
              borderRadius: radius,
              scale: 1,
              builder: (context, active) => Material(
                color: active ? RedoxRoles.surfaceContainerHighest : Colors.transparent,
                borderRadius: radius,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: radius,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        leading,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium!.copyWith(
                                  color: RedoxRoles.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                subtitle,
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
            ),
          ),
          Semantics(
            button: true,
            label: removeLabel,
            excludeSemantics: true,
            child: IconActionButton(icon: RedoxIcons.close, onPressed: onRemove),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
