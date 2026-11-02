import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/channel_folder.dart';
import '../../core/content/content_locks.dart';
import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/segmented_toggle.dart';
import '../locks/lock_scope.dart';
import 'widgets/channel_browser.dart';

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

  void _toast(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final s = await widget.sources.refresh(_source);
      setState(() {
        _source = s;
        _channels = widget.sources.channels(s);
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
    return Scaffold(
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
                  // Bütün kaynağın kilidi.
                  if (LockScope.maybeOf(context)?.profiles != null) ...[
                    const SizedBox(width: 10),
                    LockButton(lockKey: ContentLocks.folder(_source.id, const [])),
                  ],
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
                    return ChannelBrowser(
                      // Yenileyince (yeni liste) gezinme baştan.
                      key: ObjectKey(list),
                      root: _treeFor(list),
                      flat: list,
                      title: _source.name,
                      folders: _folders,
                      folderLock: (path) => ContentLocks.folder(_source.id, path),
                      onWatch: widget.onWatch,
                      favorites: widget.favorites,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
