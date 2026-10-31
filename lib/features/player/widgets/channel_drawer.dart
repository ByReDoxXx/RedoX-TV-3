import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/category_chip.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/scroll_hint_row.dart';
import '../../../core/ui/status_badge.dart';

/// Oynatıcıda soldan açılan hızlı kanal listesi (eski sürümden): başlıkta
/// kanal sayısı, kategori çipleri, altında numara · logo · ad · program.
/// Açılışta şimdiki kanal odaktadır; OK o kanala geçer. Geri kapatır (sayfa).
class ChannelDrawer extends StatefulWidget {
  const ChannelDrawer({super.key, required this.channels, required this.currentIndex, required this.onSelect});

  final List<LiveChannel> channels;
  final int currentIndex;

  /// Seçilen kanalın [channels] içindeki sırası.
  final ValueChanged<int> onSelect;

  static const width = 340.0;

  @override
  State<ChannelDrawer> createState() => _ChannelDrawerState();
}

class _ChannelDrawerState extends State<ChannelDrawer> {
  String? _category;

  List<String> get _categories => {for (final c in widget.channels) c.category}.toList();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final visible = [
      for (final (i, c) in widget.channels.indexed)
        if (_category == null || c.category == _category) i,
    ];
    final current = widget.channels[widget.currentIndex];
    return Container(
      width: ChannelDrawer.width,
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.96),
      child: SafeArea(
        right: false,
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Hızlı kanal listesi (${widget.channels.length})',
                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
              ),
              ScrollHintRow(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    for (final (i, category) in [null, ..._categories].indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      CategoryChip(
                        label: category ?? 'Tümü',
                        selected: category == _category,
                        onPressed: () => setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, k) {
                    final i = visible[k];
                    final c = widget.channels[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _Row(
                        channel: c,
                        current: identical(c, current),
                        // Açılışta şimdiki kanal odakta (başka kategoride
                        // değilse); yoksa listenin ilki.
                        autofocus: visible.contains(widget.currentIndex) ? i == widget.currentIndex : k == 0,
                        onPressed: () => widget.onSelect(i),
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

class _Row extends StatelessWidget {
  const _Row({required this.channel, required this.current, required this.autofocus, required this.onPressed});

  final LiveChannel channel;
  final bool current;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.md);
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active
            ? RedoxRoles.surfaceContainerHigh
            : current
            ? RedoxRoles.surfaceContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: current && !active ? const BorderSide(color: RedoxRoles.tertiary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${c.number}',
                    style: RedoxType.labelMd.copyWith(
                      color: RedoxRoles.tertiary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: RedoxType.tabular,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(RedoxRadius.sm),
                  child: SizedBox.square(
                    dimension: 32,
                    child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${c.streams.length} akış · ${c.programTitle}',
                        style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (c.live)
                  const SizedBox(
                    height: 14,
                    child: FittedBox(child: StatusBadge(label: 'CANLI', pulse: true)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
