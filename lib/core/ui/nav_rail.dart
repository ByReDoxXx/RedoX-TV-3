import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/form_factor.dart';
import '../theme/m3e_motion.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'redox_icon.dart';

class NavRailItem {
  const NavRailItem(this.icon, this.label);

  final RedoxIcons icon;
  final String label;
}

/// M3 Expressive gezinme rayı. Ölçü ve renkler Compose Material 3
/// belirteçlerinden (androidx: NavigationRailCollapsedTokens,
/// NavigationRailExpandedTokens, NavigationRailVerticalItemTokens,
/// NavigationRailHorizontalItemTokens, NavigationRailColorTokens):
///
/// - Daralmış: 96 dp, `surface`; öğe göstergesi 56 x 32 dp hap, etiket altta
///   (labelMedium, ikonla arası 4 dp). Yükseklik yetmezse (TV 540 dp) yalnız
///   ikon; etiketler ray açılınca görünür.
/// - Açık: modal genişletilmiş ray, 256 dp (220–360 aralığı), `surfaceContainer`,
///   uç köşeler 16 dp (CornerLarge), seviye 2 gölge. Öğe 56 dp; ikon ve etiket
///   yan yana (labelLarge, araları 8 dp), gösterge içeriği sarar (16 dp iç boşluk).
/// - Öğeler arası 4 dp; ilk öğeye kadar 44 dp üst boşluk.
/// - Renk: gösterge `secondaryContainer`, etkin ikon `onSecondaryContainer`,
///   etkin etiket `secondary`, edilgen ikon ve etiket `onSurfaceVariant`;
///   durum katmanı `onSecondaryContainer`.
///
/// Odak (D-pad) veya fare üstündeki öğe sağa doğru açılır ve adını gösterir;
/// odak ayrılınca kapanır (kullanıcı isteği). Seçili değilse hap
/// `surfaceContainerHighest` zeminle içeriğin üstünde yüzer. Bütün ray TV
/// dışında üstteki menü düğmesiyle açılır ve kapanır (dokunmatik).
/// Açıkken içeriğin üstüne biner, içeriği itmez. Gösterge sol kenarı iki
/// durumda da 20 dp'dedir; açılırken ikon yerinden oynamaz.
class RedoxNavRail extends StatefulWidget {
  const RedoxNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.footer = const [],
    this.onSelected,
    this.expanded,
    this.focusedIndex,
  });

  static const double collapsedWidth = 96;
  static const double expandedWidth = 256;
  static const double topSpace = 44;
  static const double itemSpace = 4;

  /// Daralmış öğe: gösterge 56 x 32; etiketsiz öğe 48 dp dokunma hedefi.
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;
  static const double iconOnlyItemHeight = 48;

  /// Açık öğe ve gösterge yüksekliği.
  static const double expandedItemHeight = 56;

  /// Etiketli daralmış öğe: 4 + gösterge 32 + 4 + etiket satırı + 4.
  static double collapsedLabelledItemHeight(double labelLine) => 4 + indicatorHeight + 4 + labelLine + 4;

  /// Göstergenin raydaki sol kenarı: (96 - 56) / 2.
  static const double indicatorInset = (collapsedWidth - indicatorWidth) / 2;

  final List<NavRailItem> items;

  /// Alt bölüm (örn. Ayarlar); dizinleri `items`'tan sonra devam eder.
  final List<NavRailItem> footer;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  /// null: otomatik (fare, odak, menü düğmesi). true/false: dışarıdan sabit.
  final bool? expanded;

  /// Önizleme: bu öğeyi odakta göster.
  final int? focusedIndex;

  @override
  State<RedoxNavRail> createState() => _RedoxNavRailState();
}

/// Odak halkasının öğe dışına taştığı mesafe: 2 dp ofset + 2 dp çizgi.
const double _ringRoom = 4;

class _RedoxNavRailState extends State<RedoxNavRail> {
  bool _pinned = false;

  /// Öğe başına odak düğümü (ana öğeler, sonra alt bölüm).
  final List<FocusNode> _nodes = [];

  /// Bütün ray yalnızca menü düğmesiyle (veya dışarıdan) açılır. Odak ya da
  /// fare üstü yalnızca o öğeyi sağa açar (kullanıcı isteği, 2026-10-31).
  bool get _expanded => widget.expanded ?? _pinned;

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(int index) {
    while (_nodes.length <= index) {
      _nodes.add(FocusNode(debugLabel: 'RedoxNavRail ${_nodes.length}'));
    }
    return _nodes[index];
  }

  /// Odak raya dışarıdan girince (D-pad) en yakın öğeye değil seçili öğeye
  /// gider: TV'de gezinme menüsüne girişte geçerli bölüm odaklanır
  /// (kullanıcı isteği). Ray içindeki yukarı/aşağı geçişler etkilenmez.
  void _onRailFocus(bool hasFocus) {
    if (!hasFocus) return;
    final selected = widget.selectedIndex;
    if (selected < 0 || selected >= widget.items.length + widget.footer.length) return;
    final target = _node(selected);
    if (!target.hasPrimaryFocus) target.requestFocus();
  }

  /// Rayda yukarı/aşağı ray öğeleri arasında kalır. Odaktaki öğenin hapı
  /// içeriğin üstüne açıldığından varsayılan yön araması yandaki içerik
  /// kutusunu daha yakın bulup oraya atlıyordu (Chromecast'te Ayarlar'dan
  /// yukarı → sayfadaki kutu). Uçlarda varsayılan gezinmeye bırakır.
  KeyEventResult _onRailKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final current = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    final next = current + step;
    if (current < 0 || next < 0 || next >= widget.items.length + widget.footer.length) return KeyEventResult.ignored;
    _node(next).requestFocus();
    return KeyEventResult.handled;
  }

  Duration get _duration => MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : M3EMotion.medium4;

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final formFactor = Theme.of(context).extension<RedoxMetrics>()?.formFactor ?? FormFactor.tv;
    final menuButton = formFactor != FormFactor.tv;
    final t = Theme.of(context).textTheme;
    final collapsedLabel = t.labelMedium!;
    final count = widget.items.length + widget.footer.length;
    // Kendisi odak almaz; yalnızca odağın raya girişini izler.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onRailFocus,
      onKeyEvent: _onRailKey,
      child: _rail(expanded, menuButton, collapsedLabel, count),
    );
  }

  Widget _rail(bool expanded, bool menuButton, TextStyle collapsedLabel, int count) {
    return AnimatedContainer(
      duration: _duration,
      curve: M3EMotion.standard,
      width: expanded ? RedoxNavRail.expandedWidth : RedoxNavRail.collapsedWidth,
      decoration: BoxDecoration(
        color: expanded ? RedoxRoles.surfaceContainer : RedoxRoles.surface,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(expanded ? RedoxRadius.lg : 0)),
        boxShadow: expanded ? kElevationToShadow[3] : const [],
      ),
      // Daralmışken kesilmez: odaktaki öğenin hapı rayın dışına, içeriğin
      // üstüne açılır.
      child: ClipRRect(
        clipBehavior: expanded ? Clip.antiAlias : Clip.none,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(expanded ? RedoxRadius.lg : 0)),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: RedoxNavRail.expandedWidth,
          maxWidth: RedoxNavRail.expandedWidth,
          child: LayoutBuilder(
            builder: (context, c) {
              // Daralmış etiketler ancak tüm öğeler kaymadan sığarsa gösterilir.
              final labelLine = (collapsedLabel.height ?? 1.2) * collapsedLabel.fontSize!;
              final labelled = RedoxNavRail.collapsedLabelledItemHeight(labelLine);
              final header = RedoxNavRail.topSpace + (menuButton ? 48 + RedoxNavRail.itemSpace : 0);
              final need = header + count * (labelled + RedoxNavRail.itemSpace) + 16;
              final showCollapsedLabels = need <= c.maxHeight;
              // Kaydırma alanı keser (taşan öğe alt bölümün üstüne binmesin);
              // odak halkası kesilmesin diye alanın içinde 4 dp pay var.
              return Padding(
                padding: const EdgeInsets.only(top: RedoxNavRail.topSpace - _ringRoom, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (menuButton) ...[
                      const SizedBox(height: _ringRoom),
                      _menuButton(expanded),
                      const SizedBox(height: RedoxNavRail.itemSpace - _ringRoom),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: _ringRoom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              _item(i, widget.items[i], expanded, showCollapsedLabels),
                          ],
                        ),
                      ),
                    ),
                    for (var j = 0; j < widget.footer.length; j++)
                      _item(widget.items.length + j, widget.footer[j], expanded, showCollapsedLabels),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _menuButton(bool expanded) {
    return Padding(
      padding: const EdgeInsets.only(left: RedoxNavRail.indicatorInset + 4),
      child: IconButton(
        tooltip: expanded ? RedoxIcons.menuOpen.label : RedoxIcons.menu.label,
        onPressed: widget.expanded == null ? () => setState(() => _pinned = !_pinned) : null,
        icon: RedoxIcon(expanded ? RedoxIcons.menuOpen : RedoxIcons.menu, color: RedoxRoles.onSurfaceVariant),
      ),
    );
  }

  /// Açık göstergenin içeriği saran genişliği: 16 + ikon 24 + 8 + etiket + 16.
  double _expandedIndicatorWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final w = 16 + 24 + 8 + painter.width + 16;
    painter.dispose();
    return w.clamp(RedoxNavRail.indicatorWidth, RedoxNavRail.expandedWidth - 2 * RedoxNavRail.indicatorInset);
  }

  Widget _item(int index, NavRailItem item, bool expanded, bool showCollapsedLabels) {
    final t = Theme.of(context).textTheme;
    final selected = index == widget.selectedIndex;
    final iconColor = selected ? RedoxRoles.onSecondaryContainer : RedoxRoles.onSurfaceVariant;
    final labelColor = selected ? RedoxRoles.secondary : RedoxRoles.onSurfaceVariant;
    final sideLabel = t.labelLarge!.copyWith(color: labelColor);
    final belowLabel = t.labelMedium!.copyWith(color: labelColor);
    final openWidth = _expandedIndicatorWidth(item.label, sideLabel);
    final indicatorH = expanded ? RedoxNavRail.expandedItemHeight : RedoxNavRail.indicatorHeight;
    final showBelow = !expanded && showCollapsedLabels;
    const pill = BorderRadius.all(Radius.circular(RedoxRadius.full));

    final indicator = FocusGlow(
      borderRadius: pill,
      scale: 1,
      focused: widget.focusedIndex == null ? null : widget.focusedIndex == index,
      builder: (context, active) {
        // Odakta veya fare üstünde öğe sağa açılır ve adını gösterir.
        final open = expanded || active;
        final floating = active && !expanded;
        return Semantics(
          selected: selected,
          button: true,
          label: item.label,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              focusNode: _node(index),
              onTap: widget.onSelected == null ? null : () => widget.onSelected!(index),
              customBorder: const StadiumBorder(),
              // M3 durum katmanı opaklıkları: üstüne gelme %8, odak ve basma %10.
              hoverColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.08),
              focusColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
              highlightColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
              splashColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
              child: AnimatedContainer(
                duration: _duration,
                curve: M3EMotion.standard,
                width: open ? openWidth : RedoxNavRail.indicatorWidth,
                height: indicatorH,
                decoration: BoxDecoration(
                  color: selected
                      ? RedoxRoles.secondaryContainer
                      : floating
                      ? RedoxRoles.surfaceContainerHighest
                      : Colors.transparent,
                  borderRadius: pill,
                ),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16),
                        RedoxIcon(item.icon, filled: selected, color: iconColor),
                        AnimatedOpacity(
                          opacity: open ? 1 : 0,
                          duration: open ? M3EMotion.medium4 : M3EMotion.short4,
                          curve: M3EMotion.standard,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 16),
                            child: Text(item.label, style: sideLabel, maxLines: 1, softWrap: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    final labelLine = (belowLabel.height ?? 1.2) * belowLabel.fontSize!;
    final height = expanded
        ? RedoxNavRail.expandedItemHeight
        : showBelow
        ? RedoxNavRail.collapsedLabelledItemHeight(labelLine)
        : RedoxNavRail.iconOnlyItemHeight;

    // Öğe yüksekliği göstergeyle aynı eğride değişir. İçerik geçişte kısa süre
    // taşabilir; OverflowBox taşmayı hataya çevirmeden çizer (kesmez, odak
    // halkası da öğe dışına taşar).
    return Padding(
      padding: const EdgeInsets.only(bottom: RedoxNavRail.itemSpace),
      child: AnimatedContainer(
        duration: _duration,
        curve: M3EMotion.standard,
        height: height,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: RedoxNavRail.indicatorInset),
                child: indicator,
              ),
              if (showBelow)
                SizedBox(
                  width: RedoxNavRail.collapsedWidth,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(
                      item.label,
                      style: belowLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
