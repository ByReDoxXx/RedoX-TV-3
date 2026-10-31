import 'package:flutter/material.dart';

import '../theme/m3e_motion.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'nav_rail.dart';
import 'redox_icon.dart';

/// Telefon alt menüsü. M3 Expressive kısa gezinme çubuğu ölçüleri: 64 dp
/// `surfaceContainer` kap, öğe göstergesi 56 x 32 hap (`secondaryContainer`),
/// üstte 6 dp, ikonla etiket arası 4 dp, etiket labelMedium.
///
/// Anasayfa bu çubukta yoktur; başlıktaki logoya dokununca gidilir
/// (kullanıcı isteği). Anasayfadayken hiçbir öğe seçili değildir
/// ([selectedIndex] -1).
class RedoxBottomBar extends StatelessWidget {
  const RedoxBottomBar({super.key, required this.items, this.selectedIndex = -1, this.onSelected});

  static const double barHeight = 64;
  static const double topSpace = 6;
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;

  final List<NavRailItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: RedoxRoles.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / items.length;
              // Dar ekranda gösterge yuvaya sığacak kadar daralır.
              final indicatorW = (slot - 8).clamp(40.0, indicatorWidth);
              return Row(
                children: [for (var i = 0; i < items.length; i++) Expanded(child: _slot(context, i, indicatorW))],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int index, double indicatorW) {
    final item = items[index];
    final selected = index == selectedIndex;
    final t = Theme.of(context).textTheme;
    final label = t.labelMedium!.copyWith(color: selected ? RedoxRoles.secondary : RedoxRoles.onSurfaceVariant);
    const pill = BorderRadius.all(Radius.circular(RedoxRadius.full));
    return FocusGlow(
      borderRadius: pill,
      scale: 1,
      builder: (context, active) => Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected!(index),
          customBorder: const StadiumBorder(),
          // M3 durum katmanı: üstüne gelme %8, odak ve basma %10.
          hoverColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.08),
          focusColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
          highlightColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
          splashColor: RedoxRoles.onSecondaryContainer.withValues(alpha: 0.10),
          child: Column(
            children: [
              const SizedBox(height: topSpace),
              AnimatedContainer(
                duration: M3EMotion.medium4,
                curve: M3EMotion.standard,
                width: selected ? indicatorW : indicatorHeight,
                height: indicatorHeight,
                decoration: BoxDecoration(
                  color: selected ? RedoxRoles.secondaryContainer : Colors.transparent,
                  borderRadius: pill,
                ),
                child: Center(
                  child: RedoxIcon(
                    item.icon,
                    filled: selected,
                    color: selected ? RedoxRoles.onSecondaryContainer : RedoxRoles.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                // Dar yuvada uzun etiket sığacak kadar küçülür.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(item.label, style: label, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
