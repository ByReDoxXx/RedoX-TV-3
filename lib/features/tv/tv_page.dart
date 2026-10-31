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
import '../../core/ui/status_badge.dart';
import 'tv_content.dart';
import 'widgets/channel_preview.dart';

/// Televizyon: üstte sayılı kategori çipleri, altta kanal kartı ızgarası
/// (kullanıcı seçimi: "çipler + kart ızgarası"). TV/tablet/masaüstünde sağda
/// odaktaki kanalın önizleme paneli durur (kullanıcının Stitch referansından
/// esinlenildi). Izgara tembel kurulur (SliverGrid): gerçek listelerde binlerce
/// kanal olabilir. Ray, alt menü ve Geri kök kabuktadır (RootShell).
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

  /// Kanal izlenmek istenince (oynatıcı yazılınca açılacak).
  final ValueChanged<LiveChannel>? onChannel;

  /// Izgaradaki sütun: TV/tablette önizleme panelinin yanında 3, telefonda tam
  /// genişlikte 2.
  static int columnsFor(FormFactor formFactor) => formFactor == FormFactor.phone ? 2 : 3;

  /// Önizleme paneli telefonda yoktur (yer yok).
  static bool hasPreview(FormFactor formFactor) => formFactor != FormFactor.phone;

  /// Odak halkası için ızgara kayma alanının iç payı (2 dp ofset + 2 dp çizgi
  /// + 1,08 büyüme).
  static const ringRoom = 12.0;

  @override
  State<TvPage> createState() => _TvPageState();
}

class _TvPageState extends State<TvPage> {
  /// Seçili kategori; null "Tümü".
  String? _category;

  /// Önizlemedeki kanal (odaktaki veya son dokunulan); null ise ilk kanal.
  LiveChannel? _previewed;

  List<LiveChannel> get _channels => _category == null
      ? widget.content.channels
      : [for (final c in widget.content.channels) if (c.category == _category) c];

  void _select(String? category) => setState(() {
    _category = category;
    _previewed = null;
  });

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final padding = PageLayout.scrollPadding(context, metrics);
    final channels = _channels;
    final header = AppHeader(
      clock: widget.clock,
      profileName: widget.profileName,
      onHome: widget.onHome,
      onMore: widget.onMore,
      onRemote: () {},
    );
    if (!TvPage.hasPreview(metrics.formFactor)) {
      // Telefon: sayfa tek parça kayar.
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
            sliver: SliverToBoxAdapter(child: header),
          ),
          SliverToBoxAdapter(child: _chips(padding)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, padding.bottom),
            sliver: _grid(context, channels, metrics, padding.left + padding.right, preview: false),
          ),
        ],
      );
    }
    // TV/tablet: başlık ve çipler sabit; ızgara kendi içinde kayar, önizleme
    // paneli sağda sabit durur.
    final previewed = _previewed ?? (channels.isEmpty ? null : channels.first);
    const room = TvPage.ringRoom;
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.only(left: padding.left, right: padding.right), child: header),
          _chips(padding),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: padding.left - room, right: padding.right),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(room),
                            sliver: _grid(context, channels, metrics, box.maxWidth, preview: true, inset: room),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24 - room),
                  if (previewed != null)
                    Padding(
                      padding: const EdgeInsets.only(top: room),
                      child: SizedBox(
                        width: ChannelPreview.width,
                        child: ChannelPreview(channel: previewed, onWatch: () => widget.onChannel?.call(previewed)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sayılı çipler; yatay kayar, kayma alanı ekran kenarına kadar uzanır.
  Widget _chips(EdgeInsets padding) {
    final all = widget.content.channels;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, 6),
      child: Row(
        children: [
          for (final (i, category) in [null, ...widget.content.categories].indexed) ...[
            if (i > 0) const SizedBox(width: 12),
            CategoryChip(
              label: category ?? 'Tümü',
              count: category == null ? all.length : all.where((c) => c.category == category).length,
              selected: category == _category,
              onPressed: () => _select(category),
            ),
          ],
        ],
      ),
    );
  }

  /// Kanal ızgarası. [taken]: genişlikten düşülecek yatay dolgu.
  Widget _grid(
    BuildContext context,
    List<LiveChannel> channels,
    RedoxMetrics metrics,
    double taken, {
    required bool preview,
    double inset = 0,
  }) {
    final gutter = metrics.gutter;
    final columns = TvPage.columnsFor(metrics.formFactor);
    if (channels.isEmpty) {
      return SliverToBoxAdapter(
        child: Text(
          'Bu kategoride kanal yok.',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
      );
    }
    final width = preview ? taken - 2 * inset : MediaQuery.sizeOf(context).width - taken;
    final cell = (width - gutter * (columns - 1)) / columns;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: gutter,
        crossAxisSpacing: gutter,
        mainAxisExtent: ChannelCard.heightFor(context, cell, withNext: !preview),
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final c = channels[i];
        final card = ChannelCard(
          width: cell,
          channelName: c.name,
          number: c.number,
          // Tür yazılmaz: dar kartta "saat · tür" kesiliyordu (4K görüntü).
          timeRange: c.timeRange,
          programTitle: c.programTitle,
          progress: c.progress,
          accent: c.accent,
          // "Sonraki" 3 sütunlu dar kartta kesiliyordu; önizleme panelinde var.
          next: preview ? null : c.next,
          badge: c.live ? const StatusBadge(label: 'CANLI', pulse: true) : null,
          artwork: ArtworkFallback(name: c.name, icon: RedoxIcons.television),
          // Dokunmatik/fare: önce önizle, ikinci dokunuşta izle. D-pad'de
          // odak önizler, OK izler.
          onPressed: () => preview && _previewed != c ? setState(() => _previewed = c) : widget.onChannel?.call(c),
        );
        if (!preview) return card;
        // Odaktaki kart önizlemeye gelir (kendisi odak almaz, izler).
        return Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) {
            if (focused && _previewed != c) setState(() => _previewed = c);
          },
          child: card,
        );
      }, childCount: channels.length),
    );
  }
}
