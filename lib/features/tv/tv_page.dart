import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/artwork_fallback.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/channel_card.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/status_badge.dart';
import 'tv_content.dart';

/// Televizyon: üstte kategori çipleri, altta kanal kartı ızgarası (kullanıcı
/// seçimi: "çipler + kart ızgarası"). Sayfa tek parça kayar; ızgara tembel
/// kurulur (SliverGrid): gerçek listelerde binlerce kanal olabilir.
/// Ray, alt menü ve Geri kök kabuktadır (RootShell).
class TvPage extends StatefulWidget {
  const TvPage({
    super.key,
    required this.content,
    required this.clock,
    required this.profileName,
    this.onHome,
    this.onMore,
    this.onChannel,
  });

  final TvContent content;
  final String clock;
  final String profileName;

  /// Telefonda logoya dokununca.
  final VoidCallback? onHome;

  /// Telefonda "Diğer" düğmesine basılınca.
  final VoidCallback? onMore;

  /// Kanal kartı seçilince (oynatıcı yazılınca açılacak).
  final ValueChanged<LiveChannel>? onChannel;

  /// Izgaradaki sütun: TV/tablet/masaüstü 4, telefon 2.
  static int columnsFor(FormFactor formFactor) => formFactor == FormFactor.phone ? 2 : 4;

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> {
  /// Seçili kategori; null "Tümü".
  String? _category;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final gutter = metrics.gutter;
    final t = Theme.of(context).textTheme;
    final channels = _category == null
        ? widget.content.channels
        : [for (final c in widget.content.channels) if (c.category == _category) c];
    return LayoutBuilder(
      builder: (context, box) {
        final padding = PageLayout.scrollPadding(context, metrics);
        final columns = TvPage.columnsFor(metrics.formFactor);
        final cell = (box.maxWidth - padding.horizontal - gutter * (columns - 1)) / columns;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppHeader(
                      clock: widget.clock,
                      profileName: widget.profileName,
                      onHome: widget.onHome,
                      onMore: widget.onMore,
                      onRemote: () {},
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(title: 'Televizyon', subtitle: '${channels.length} kanal'),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              // Çipler yatay kayar; kayma alanı ekran kenarına kadar uzanır,
              // odak halkası için alt/üst 6 dp pay.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, 6),
                child: Row(
                  children: [
                    for (final (i, category) in [null, ...widget.content.categories].indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      CategoryChip(
                        label: category ?? 'Tümü',
                        selected: category == _category,
                        onPressed: () => setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, padding.bottom),
              sliver: channels.isEmpty
                  ? SliverToBoxAdapter(
                      child: Text(
                        'Bu kategoride kanal yok.',
                        style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: gutter,
                        crossAxisSpacing: gutter,
                        mainAxisExtent: ChannelCard.heightFor(context, cell),
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final c = channels[i];
                        return ChannelCard(
                          width: cell,
                          channelName: c.name,
                          number: c.number,
                          programTitle: c.programTitle,
                          // Tür yazılmaz: TV'de ~190 dp kartta "saat · tür"
                          // kesiliyordu (4K görüntü).
                          timeRange: c.timeRange,
                          progress: c.progress,
                          accent: c.accent,
                          badge: c.live ? const StatusBadge(label: 'CANLI', pulse: true) : null,
                          artwork: ArtworkFallback(name: c.name, icon: RedoxIcons.television),
                          onPressed: () => widget.onChannel?.call(c),
                        );
                      }, childCount: channels.length),
                    ),
            ),
          ],
        );
      },
    );
  }
}
