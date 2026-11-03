import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_type.dart';
import 'focus_glow.dart';

/// Filtre çipi (DESIGN.md "Filter Chips"). Boşta en yüksek-1 kap; seçili kızıl
/// → kor degrade, beyaz yazı. Degrade ucu amber tohum yerine
/// RedoxAccent.ember'dir: beyaz yazı amberde 2,31:1 kalıyordu.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onPressed,
    this.focused,
    this.count,
    this.autofocus = false,
  });

  final bool autofocus;

  /// Öğe sayısı: etiketin yanında küçük hap ("Spor 4").
  final int? count;

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final bool? focused;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!;
    final radius = BorderRadius.circular(RedoxRadius.full);
    return FocusGlow(
      borderRadius: radius,
      focused: focused,
      builder: (context, _) => Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? null : RedoxRoles.surfaceContainerHigh,
            gradient: selected ? const LinearGradient(colors: [RedoxSeeds.crimson, RedoxAccent.ember]) : null,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: style.copyWith(color: selected ? Colors.white : RedoxRoles.onSurfaceVariant)),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    // Sayı hapı: seçiliyken koyu perde, değilken bir ton yüksek kap.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? RedoxSeeds.obsidian.withValues(alpha: 0.3)
                            : RedoxRoles.surfaceContainerHighest,
                        borderRadius: radius,
                      ),
                      child: Text(
                        '$count',
                        style: style.copyWith(
                          color: selected ? Colors.white : RedoxRoles.onSurfaceVariant,
                          fontFeatures: RedoxType.tabular,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
