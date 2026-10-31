import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';

/// Filtre çipi (DESIGN.md "Filter Chips"). Boşta en yüksek-1 kap; seçili kızıl
/// → kor degrade, beyaz yazı. Degrade ucu spec'teki #FF9E1B yerine
/// RedoxAccent.ember'dir: beyaz yazı amberde 2,07:1 kalıyordu.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onPressed,
    this.focused,
  });

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
            gradient: selected
                ? const LinearGradient(colors: [RedoxSeeds.crimson, RedoxAccent.ember])
                : null,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text(
                label,
                style: style.copyWith(
                  color: selected ? Colors.white : RedoxRoles.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
