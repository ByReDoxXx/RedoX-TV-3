import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/playback/engine/media_kit_engine.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/segmented_toggle.dart';
import '../radio/widgets/station_avatar.dart';
import 'split_screen.dart';

/// Bölünmüş Ekran: 2'li ya da 4'lü canlı yayın ızgarası. Ses yalnız odaktaki
/// (dokunmatikte son seçilen) karodan gelir; diğerleri sessiz oynar. Boş
/// karoda OK kanal seçtirir; dolu karoda OK: Tam ekran / Kanalı değiştir /
/// Kaldır. Tam ekrana geçerken karoların çözücüleri kapatılır (zayıf TV'de
/// donanım çözücü sayısı sınırlı), dönüşte yeniden açılır.
class SplitScreenPage extends StatefulWidget {
  const SplitScreenPage({
    super.key,
    required this.split,
    required this.channels,
    required this.clock,
    required this.profileName,
    this.onWatch,
    this.engineFactory,
    this.onHome,
    this.onMore,
    this.onProfile,
  });

  final SplitScreen split;

  /// Seçilebilen kanallar.
  final List<LiveChannel> channels;

  /// Tam ekran; dönünce tamamlanır.
  final Future<void> Function(LiveChannel)? onWatch;

  /// Oynatma motoru; null ise media_kit (testlerde sahte motor).
  final PlaybackEngine Function()? engineFactory;
  final String clock;
  final String profileName;
  final VoidCallback? onHome;
  final VoidCallback? onMore;
  final VoidCallback? onProfile;

  @override
  State<SplitScreenPage> createState() => _SplitScreenPageState();
}

class _SplitScreenPageState extends State<SplitScreenPage> {
  final _engines = <int, (LiveChannel, PlaybackEngine)>{};
  int _audio = 0;
  bool _suspended = false;

  SplitScreen get _split => widget.split;

  @override
  void initState() {
    super.initState();
    _split.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    _split.removeListener(_sync);
    _closeAll();
    super.dispose();
  }

  void _closeAll() {
    for (final (_, e) in _engines.values) {
      unawaited(e.dispose());
    }
    _engines.clear();
  }

  /// Karolarla motorları eşler: yeni kanal açılır, boşalan kapanır.
  void _sync() {
    if (_suspended) return;
    final slots = _split.slots;
    for (final i in _engines.keys.toList()) {
      final c = i < slots.length ? slots[i] : null;
      if (c != _engines[i]!.$1) unawaited(_engines.remove(i)!.$2.dispose());
    }
    for (final (i, c) in slots.indexed) {
      if (c == null || _engines.containsKey(i) || c.streams.isEmpty) continue;
      final e = (widget.engineFactory ?? MediaKitEngine.new)();
      _engines[i] = (c, e);
      unawaited(e.setMuted(i != _audio));
      unawaited(e.open(c.streams.first));
    }
    if (mounted) setState(() {});
  }

  void _focusAudio(int i) {
    if (i == _audio) return;
    setState(() => _audio = i);
    for (final MapEntry(key: k, value: (_, e)) in _engines.entries) {
      unawaited(e.setMuted(k != i));
    }
  }

  Future<void> _watch(LiveChannel c) async {
    final onWatch = widget.onWatch;
    if (onWatch == null) return;
    setState(() => _suspended = true);
    _closeAll();
    try {
      await onWatch(c);
    } finally {
      if (mounted) {
        _suspended = false;
        _sync();
      }
    }
  }

  Future<void> _pick(int i) async {
    final c = await showDialog<LiveChannel>(
      context: context,
      builder: (_) => _ChannelPicker(channels: widget.channels),
    );
    if (c != null) _split.put(i, c);
  }

  Future<void> _actions(int i, LiveChannel c) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => _TileActions(channel: c),
    );
    switch (choice) {
      case 'watch':
        await _watch(c);
      case 'change':
        await _pick(i);
      case 'remove':
        _split.clear(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    final padding = PageLayout.scrollPadding(context, metrics);
    final slots = _split.slots;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, phone ? 16 : padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            clock: widget.clock,
            profileName: widget.profileName,
            onHome: widget.onHome,
            onMore: widget.onMore,
            onProfile: widget.onProfile,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Row(
              children: [
                // En geniş düzen 2 ise (SplitScreen.maxLayout) anahtar yok.
                if (_split.maxLayout > 2) ...[
                  SegmentedToggle(
                    segments: const [
                      ToggleSegment("2'li", RedoxIcons.cardView),
                      ToggleSegment("4'lü", RedoxIcons.splitScreen),
                    ],
                    selectedIndex: _split.layout == 2 ? 0 : 1,
                    onChanged: (i) => _split.layout = i == 0 ? 2 : SplitScreen.maxSlots,
                  ),
                  const SizedBox(width: 16),
                ],
                Flexible(
                  child: Text(
                    metrics.formFactor != FormFactor.tv
                        ? 'Ses seçili karodan gelir.'
                        : 'Ses odaktaki karodan gelir. OK: kanal ekle, tam ekran ya da kaldır.',
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                // 4'lü: 2 × 2; 2'li: TV'de yan yana, telefonda alt alta.
                final cols = slots.length == 2 && phone ? 1 : 2;
                final rows = (slots.length / cols).ceil();
                const gap = 12.0;
                var w = (box.maxWidth - gap * (cols - 1)) / cols;
                var h = w * 9 / 16;
                final maxH = (box.maxHeight - gap * (rows - 1)) / rows;
                if (h > maxH) {
                  h = maxH;
                  w = h * 16 / 9;
                }
                return Center(
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (i, c) in slots.indexed)
                        SizedBox(
                          width: w,
                          height: h,
                          child: _Tile(
                            channel: c,
                            engine: _engines[i]?.$2,
                            audio: i == _audio && c != null,
                            autofocus: i == 0,
                            onFocus: () => _focusAudio(i),
                            onPressed: () => c == null ? _pick(i) : _actions(i, c),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.channel,
    required this.engine,
    required this.audio,
    required this.onFocus,
    required this.onPressed,
    this.autofocus = false,
  });

  final LiveChannel? channel;
  final PlaybackEngine? engine;
  final bool audio;
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return FocusGlow(
      borderRadius: radius,
      scale: 1.02,
      builder: (context, active) => Material(
        color: RedoxRoles.surfaceContainerLowest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            onFocus();
            onPressed();
          },
          autofocus: autofocus,
          onFocusChange: (v) {
            if (v) onFocus();
          },
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Semantics(
            button: true,
            label: c == null ? 'Kanal ekle' : c.name,
            child: c == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: active ? RedoxSeeds.amber : RedoxRoles.outlineVariant, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RedoxIcon(
                            RedoxIcons.add,
                            size: 36,
                            color: active ? RedoxSeeds.amber : RedoxRoles.onSurfaceVariant,
                          ),
                          const SizedBox(height: 6),
                          Text('Kanal ekle', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: StationAvatar(station: c, size: double.infinity, radius: 0),
                      ),
                      if (engine case final e?) Positioned.fill(child: e.view(fit: BoxFit.cover)),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        right: 10,
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xB3000000),
                                  borderRadius: BorderRadius.circular(RedoxRadius.full),
                                ),
                                child: Text(
                                  '${c.number}  ${c.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelLarge!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            if (audio) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: RedoxSeeds.crimson, shape: BoxShape.circle),
                                child: const RedoxIcon(RedoxIcons.volume, color: Colors.white, size: 16),
                              ),
                            ],
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

/// Dolu karonun eylemleri.
class _TileActions extends StatelessWidget {
  const _TileActions({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget item(String id, RedoxIcons icon, String label, {bool autofocus = false}) => ListTile(
      autofocus: autofocus,
      leading: RedoxIcon(icon, color: RedoxSeeds.gold),
      title: Text(label, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
      onTap: () => Navigator.pop(context, id),
    );
    return SimpleDialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      title: Text(channel.name, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
      children: [
        item('watch', RedoxIcons.fullscreen, 'Tam ekran', autofocus: true),
        item('change', RedoxIcons.sync, 'Kanalı değiştir'),
        item('remove', RedoxIcons.close, 'Kaldır'),
      ],
    );
  }
}

/// Kanal seçici: numaralı liste.
class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({required this.channels});

  final List<LiveChannel> channels;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Kanal seç', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: channels.length,
                itemExtent: 56,
                itemBuilder: (context, i) {
                  final c = channels[i];
                  return ListTile(
                    autofocus: i == 0,
                    leading: StationAvatar(station: c, size: 36, radius: RedoxRadius.sm),
                    title: Text(
                      '${c.number}  ${c.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                    ),
                    subtitle: Text(c.category, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
