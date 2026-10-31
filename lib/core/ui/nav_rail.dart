import 'package:flutter/material.dart';

import '../theme/m3e_motion.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'redox_icon.dart';

class NavRailItem {
  const NavRailItem(this.icon, this.label, {this.tint = RedoxRoles.onSurfaceVariant});

  final RedoxIcons icon;
  final String label;

  /// Seçili değilken ikon rengi (bölüm rengi; metin dışı, zeminde >= 3:1).
  final Color tint;
}

/// Gezinme rayı. Yalnız ikonlarla daralmış durur; üstüne gelince veya içine
/// odak girince açılır, ayrılınca kapanır (proje kuralı). Açılış eğrisi
/// cubic-bezier(0.2, 0, 0, 1) (DESIGN.md). Seçili öğe sol kenara yaslı,
/// asimetrik hap. Açıkken içeriğin üstüne biner, içeriği itmez.
///
/// Ölçüler: daralmış 96, açık 288 dp (M3 Expressive rayı ve zip'teki tasarım).
/// Öğe yüksekliği her biçimde 48 dp: TV tuvali 540 dp yüksekliğindedir ve
/// 8 ana + 1 alt öğe 56 dp ile sığmaz (testte 156 dp taşma ölçüldü). Ana öğeler
/// daha kısa ekranlarda kayar; alt bölüm sabit kalır.
class RedoxNavRail extends StatefulWidget {
  const RedoxNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.footer = const [],
    this.leading,
    this.onSelected,
    this.expanded,
    this.focusedIndex,
  });

  static const double collapsedWidth = 96;
  static const double expandedWidth = 288;
  static const double itemHeight = 48;

  final List<NavRailItem> items;

  /// Alt bölüm (örn. Ayarlar); dizinleri `items`'tan sonra devam eder.
  final List<NavRailItem> footer;
  final int selectedIndex;
  final Widget? leading;
  final ValueChanged<int>? onSelected;

  /// null: otomatik (fare/odak). true/false: dışarıdan sabit.
  final bool? expanded;

  /// Önizleme: bu öğeyi odakta göster.
  final int? focusedIndex;

  @override
  State<RedoxNavRail> createState() => _RedoxNavRailState();
}

class _RedoxNavRailState extends State<RedoxNavRail> {
  bool _hovered = false;
  bool _focusInside = false;

  bool get _expanded => widget.expanded ?? (_hovered || _focusInside);

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    final duration = MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : M3EMotion.medium4;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (f) => setState(() => _focusInside = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: duration,
          curve: M3EMotion.standard,
          width: expanded ? RedoxNavRail.expandedWidth : RedoxNavRail.collapsedWidth,
          // Daralmış: dinlenen ray (low). Açık: yan çekmece (high, "floating").
          decoration: BoxDecoration(
            color: expanded ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainerLow,
            border: Border(
              right: BorderSide(color: RedoxRoles.outlineVariant.withValues(alpha: 0.2)),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: RedoxNavRail.expandedWidth,
              maxWidth: RedoxNavRail.expandedWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.leading != null) ...[
                    SizedBox(
                      width: RedoxNavRail.collapsedWidth,
                      child: Center(child: widget.leading),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < widget.items.length; i++) _item(i, widget.items[i], expanded),
                        ],
                      ),
                    ),
                  ),
                  for (var j = 0; j < widget.footer.length; j++)
                    _item(widget.items.length + j, widget.footer[j], expanded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int index, NavRailItem item, bool expanded) {
    final selected = index == widget.selectedIndex;
    final fg = selected ? RedoxRoles.onPrimaryContainer : item.tint;
    final label = selected ? RedoxRoles.onPrimaryContainer : RedoxRoles.onSurfaceVariant;
    // Sol kenara yaslı asimetrik hap: sol köşeler düz, sağ köşeler tam yuvarlak.
    const shape = BorderRadius.horizontal(right: Radius.circular(RedoxRadius.full));
    final width = (expanded ? RedoxNavRail.expandedWidth : RedoxNavRail.collapsedWidth) - 12;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedContainer(
        duration: MediaQuery.maybeDisableAnimationsOf(context) == true ? Duration.zero : M3EMotion.medium4,
        curve: M3EMotion.standard,
        width: width,
        height: RedoxNavRail.itemHeight,
        child: FocusGlow(
          borderRadius: shape,
          focused: widget.focusedIndex == null ? null : widget.focusedIndex == index,
          builder: (context, _) => Material(
            color: selected ? RedoxRoles.primaryContainer : Colors.transparent,
            borderRadius: shape,
            child: InkWell(
              onTap: widget.onSelected == null ? null : () => widget.onSelected!(index),
              borderRadius: shape,
              focusColor: Colors.transparent,
              hoverColor: RedoxRoles.surfaceContainerHigh,
              child: Row(
                children: [
                  SizedBox(
                    width: RedoxNavRail.collapsedWidth - 12,
                    child: Center(child: RedoxIcon(item.icon, filled: selected, color: fg)),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: expanded ? 1 : 0,
                      duration: M3EMotion.short4,
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(color: label),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
