import 'package:flutter/material.dart';

import '../../core/content/epg_program.dart';
import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/category_chip.dart';
import '../../core/ui/channel_tile.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/scroll_hint_row.dart';
import '../../core/ui/segmented_toggle.dart';
import 'tv_content.dart';
import 'widgets/channel_preview.dart';
import 'widgets/epg_grid.dart';

/// Televizyon: üstte sayılı kategori çipleri ve görünüm anahtarı (Kart
/// görünümü | EPG çizelgesi), altta seçili görünüm. Kart görünümünde
/// TV/tablet/masaüstünde sağda önizleme paneli durur: bir kanalda ilk OK
/// (dokunma) önizler, aynı kanalda ikinci OK tam ekrana geçer (kullanıcının
/// Stitch referansından esinlenildi). Izgara ve çizelge tembel kurulur:
/// gerçek listelerde binlerce kanal olabilir. Ray, alt menü ve Geri kök
/// kabuktadır (RootShell).
/// Televizyon sayfasının alt görünümleri.
enum TvView { cards, epg }

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

  /// Kanal tam ekranda izlenmek istenince.
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

  /// Önizlemedeki kanal (son OK'e basılan / dokunulan); null ise panelde
  /// yönerge durur.
  LiveChannel? _previewed;

  TvView _view = TvView.cards;

  List<LiveChannel> get _channels => _category == null
      ? widget.content.channels
      : [
          for (final c in widget.content.channels)
            if (c.category == _category) c,
        ];

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
    );
    final phone = !TvPage.hasPreview(metrics.formFactor);
    if (phone && _view == TvView.cards) {
      // Telefon kart görünümü: sayfa tek parça kayar.
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
            sliver: SliverToBoxAdapter(child: header),
          ),
          SliverToBoxAdapter(child: _filters(padding, phone)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding.left, 16, padding.right, padding.bottom),
            sliver: _grid(context, channels, metrics, preview: false),
          ),
        ],
      );
    }
    // Başlık ve çipler sabit; ızgara/çizelge kendi içinde kayar, önizleme
    // paneli sağda sabit durur.
    final body = switch (_view) {
      TvView.epg => EpgGrid(
        channels: channels,
        scheduleOf: widget.content.scheduleOf,
        now: EpgProgram.parseClock(widget.clock) ?? 0,
        compact: phone,
        onChannel: widget.onChannel,
        padding: EdgeInsets.only(left: padding.left, right: padding.right, bottom: phone ? padding.bottom : 0),
      ),
      TvView.cards => _cardsWithPreview(context, channels, metrics, padding),
    };
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: phone ? 0 : padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: header,
          ),
          _filters(padding, phone),
          if (_view == TvView.epg) const SizedBox(height: 6),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// Kart ızgarası (solda) ve önizleme paneli (sağda): TV/tablet.
  Widget _cardsWithPreview(BuildContext context, List<LiveChannel> channels, RedoxMetrics metrics, EdgeInsets padding) {
    const room = TvPage.ringRoom;
    final previewed = _previewed;
    return Padding(
      padding: EdgeInsets.only(left: padding.left - room, right: padding.right),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(room),
                  sliver: _grid(context, channels, metrics, preview: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24 - room),
          Padding(
            padding: const EdgeInsets.only(top: room),
            child: SizedBox(
              width: ChannelPreview.width,
              child: previewed == null
                  ? ChannelPreviewHint(touch: metrics.formFactor != FormFactor.tv)
                  : ChannelPreview(channel: previewed, onWatch: () => widget.onChannel?.call(previewed)),
            ),
          ),
        ],
      ),
    );
  }

  /// Çipler (yatay kayar) ve sağda görünüm anahtarı.
  Widget _filters(EdgeInsets padding, bool phone) => Row(
    children: [
      Expanded(child: _chips(padding)),
      Padding(
        padding: EdgeInsets.only(top: 16, bottom: 6, right: padding.right),
        child: SegmentedToggle(
          segments: const [
            ToggleSegment('Kart görünümü', RedoxIcons.cardView),
            ToggleSegment('EPG çizelgesi', RedoxIcons.epg),
          ],
          // Seçili görünüm yalnız ikon: çiplere yer kalsın.
          labelUnselectedOnly: true,
          selectedIndex: _view.index,
          iconOnly: phone,
          onChanged: (i) => setState(() => _view = TvView.values[i]),
        ),
      ),
    ],
  );

  /// Sayılı çipler; yatay kayar, kayma alanı görünüm anahtarına kadar uzanır.
  Widget _chips(EdgeInsets padding) {
    final all = widget.content.channels;
    const room = TvPage.ringRoom;
    // Kayma alanı sayfa kenarında başlar: ekran kenarına uzansaydı odakla
    // kayan çip sol rayın altına girerdi.
    return Padding(
      padding: EdgeInsets.only(left: padding.left - room),
      // Kaydırılabilen uçta "<" / ">" oku (kullanıcı isteği).
      child: ScrollHintRow(
        padding: const EdgeInsets.fromLTRB(room, 16, 12, 6),
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
      ),
    );
  }

  /// Kanal ızgarası; [preview]: önizleme paneli var (TV/tablet).
  Widget _grid(BuildContext context, List<LiveChannel> channels, RedoxMetrics metrics, {required bool preview}) {
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
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: gutter,
        crossAxisSpacing: gutter,
        mainAxisExtent: ChannelTile.heightFor(context),
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final c = channels[i];
        return ChannelTile(
          channel: c,
          selected: preview && _previewed == c,
          // İlk OK/dokunma önizler, aynı kanalda ikincisi tam ekran açar.
          // Telefonda panel yok: doğrudan tam ekran.
          onPressed: () => preview && _previewed != c ? setState(() => _previewed = c) : widget.onChannel?.call(c),
        );
      }, childCount: channels.length),
    );
  }
}
