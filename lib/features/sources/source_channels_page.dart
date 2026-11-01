import 'dart:async';

import 'package:flutter/material.dart';

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
import '../radio/widgets/station_avatar.dart';

/// Klasör içi (eski "Klasör içi" ekranı): listenin kanalları; OK tam ekran.
/// Üstte Yenile (adresle eklendiyse) ve Sil.
class SourceChannelsPage extends StatefulWidget {
  const SourceChannelsPage({super.key, required this.sources, required this.source, this.onWatch});

  final UserSources sources;
  final UserSource source;
  final Future<void> Function(List<LiveChannel> channels, int index)? onWatch;

  @override
  State<SourceChannelsPage> createState() => _SourceChannelsPageState();
}

class _SourceChannelsPageState extends State<SourceChannelsPage> {
  late UserSource _source = widget.source;
  late Future<List<LiveChannel>> _channels = widget.sources.channels(_source);
  bool _busy = false;

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
              Expanded(
                child: FutureBuilder(
                  future: _channels,
                  builder: (context, snap) {
                    final list = snap.data;
                    if (list == null) return const SizedBox.shrink();
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemExtent: 64,
                      itemCount: list.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ChannelRow(
                          channel: list[i],
                          autofocus: i == 0,
                          onPressed: widget.onWatch == null ? null : () => unawaited(widget.onWatch!(list, i)),
                        ),
                      ),
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

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, this.onPressed, this.autofocus = false});

  final LiveChannel channel;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
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
  }
}
