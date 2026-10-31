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
/// Ortadaki öğe (kullanıcı isteği: Anasayfa) 56 dp kızıl yuvarlak düğmedir:
/// FAB rolleri (`primaryContainer` / `onPrimaryContainer`). Düğmenin alt
/// kenarı öteki göstergelerle hizalıdır, üstü çubuktan [lift] kadar taşar;
/// etiketi öteki etiketlerle aynı satırdadır.
///
/// Çubuğun yüksekliği taşan payı da kapsar (düğmenin üst kısmına da
/// dokunulabilsin); payın düğme dışındaki kısmı saydamdır ve dokunuşu alttaki
/// içeriğe geçirir. Scaffold'da `extendBody: true` ile kullanılır.
class RedoxBottomBar extends StatelessWidget {
  const RedoxBottomBar({
    super.key,
    required this.items,
    required this.centerIndex,
    required this.selectedIndex,
    this.onSelected,
  });

  static const double barHeight = 64;
  static const double topSpace = 6;
  static const double indicatorWidth = 56;
  static const double indicatorHeight = 32;
  static const double centerSize = 56;

  /// Orta düğmenin çubuktan yukarı taşan kısmı: alt kenarı gösterge altında.
  static const double lift = centerSize - (topSpace + indicatorHeight);

  final List<NavRailItem> items;

  /// Kızıl yuvarlak düğme olarak çizilen öğe.
  final int centerIndex;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  /// Çubuğun toplam yüksekliği (taşma payı ve sistem gezinme alanı dahil).
  static double heightOf(BuildContext context) => lift + barHeight + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: lift + barHeight + bottomInset,
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = box.maxWidth / items.length;
          // Dar ekranda (360 dp / 7 = 51 dp) gösterge yuvaya sığacak kadar daralır.
          final indicatorW = (slot - 8).clamp(40.0, indicatorWidth);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: lift,
                bottom: 0,
                child: Material(
                  color: RedoxRoles.surfaceContainer,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(child: _slot(context, i, indicatorW)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: slot * centerIndex + (slot - centerSize) / 2,
                top: 0,
                width: centerSize,
                height: centerSize,
                child: _centerButton(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _slot(BuildContext context, int index, double indicatorW) {
    final item = items[index];
    final selected = index == selectedIndex;
    final center = index == centerIndex;
    final t = Theme.of(context).textTheme;
    final label = t.labelMedium!.copyWith(
      color: selected ? RedoxRoles.secondary : RedoxRoles.onSurfaceVariant,
    );
    final text = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      // 360 dp ekranda uzun etiket (Anasayfa) yuvaya sığacak kadar küçülür.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(item.label, style: label, maxLines: 1, softWrap: false),
      ),
    );
    if (center) {
      // Orta yuvada yalnız etiket; düğme ayrı katmanda, yuvanın üstündedir.
      return Semantics(
        excludeSemantics: true,
        child: Column(
          children: [
            const SizedBox(height: topSpace + indicatorHeight + 4),
            text,
          ],
        ),
      );
    }
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
              text,
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    final item = items[centerIndex];
    final selected = centerIndex == selectedIndex;
    return FocusGlow(
      borderRadius: BorderRadius.circular(centerSize / 2),
      builder: (context, _) => Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: Material(
          color: RedoxRoles.primaryContainer,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: RedoxSeeds.obsidian,
          child: InkWell(
            onTap: onSelected == null ? null : () => onSelected!(centerIndex),
            customBorder: const CircleBorder(),
            child: Center(
              child: RedoxIcon(item.icon, filled: selected, color: RedoxRoles.onPrimaryContainer, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
