import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_shapes.dart';
import 'focus_glow.dart';
import 'redox_icon.dart';

class ToggleSegment {
  const ToggleSegment(this.label, this.icon);

  final String label;
  final RedoxIcons icon;
}

/// İki-üç seçenekli görünüm anahtarı (örn. Kart görünümü / EPG zaman çizelgesi).
/// Seçili parça kızıl kap; diğerleri yazı rengiyle.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.selectedIndex,
    this.onChanged,
    this.focusedIndex,
  });

  final List<ToggleSegment> segments;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  /// Önizleme: bu parçayı odakta göster.
  final int? focusedIndex;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final inner = BorderRadius.circular(RedoxRadius.md);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: BorderRadius.circular(RedoxRadius.lg),
        border: Border.fromBorderSide(RedoxElevation.restingBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++)
            FocusGlow(
              borderRadius: inner,
              focused: focusedIndex == null ? null : focusedIndex == i,
              builder: (context, _) {
                final selected = i == selectedIndex;
                final fg = selected ? RedoxRoles.onPrimaryContainer : RedoxRoles.onSurfaceVariant;
                return Material(
                  color: selected ? RedoxRoles.primaryContainer : Colors.transparent,
                  borderRadius: inner,
                  child: InkWell(
                    onTap: onChanged == null ? null : () => onChanged!(i),
                    borderRadius: inner,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RedoxIcon(segments[i].icon, color: fg, size: 18),
                          const SizedBox(width: 8),
                          Text(segments[i].label, style: style.copyWith(color: fg)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
