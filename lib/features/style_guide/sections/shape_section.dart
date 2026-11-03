import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_spacing.dart';
import '../../../core/theme/redox_type.dart';
import '../widgets/section_frame.dart';

/// 4. Şekil, boşluk ve derinlik.
class ShapeSection extends StatelessWidget {
  const ShapeSection({super.key});

  static const _radii = <String, double>{
    'xs 4 · onay kutusu': RedoxRadius.xs,
    'sm 8 · giriş, rozet': RedoxRadius.sm,
    'md 12': RedoxRadius.md,
    'lg 16 · kart, diyalog': RedoxRadius.lg,
    'xl 24 · vitrin': RedoxRadius.xl,
    'full · düğme, çip': RedoxRadius.full,
  };

  static const _space = <String, double>{
    'xs': RedoxSpace.xs,
    'sm': RedoxSpace.sm,
    'md': RedoxSpace.md,
    'lg · gutter · margin': RedoxSpace.lg,
    'xl': RedoxSpace.xl,
    'gutter-tv': RedoxSpace.gutterTv,
    'margin-tv': RedoxSpace.marginTv,
  };

  static const _levels = <String, Color>{
    '0 · tuval (gece laciverti)': RedoxSeeds.obsidian,
    '1 · kart (container)': RedoxRoles.surfaceContainer,
    '2 · üst katman (high)': RedoxRoles.surfaceContainerHigh,
    '3 · diyalog (highest)': RedoxRoles.surfaceContainerHighest,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final label = t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular);
    return SectionFrame(
      index: 4,
      title: 'Şekil, boşluk, derinlik',
      subtitle:
          'Köşe ve boşluk dp · derinlik gölgeyle değil yüzey parlaklığıyla · odakta kızıl halka + aura + amber ışıma.',
      accent: RedoxSeeds.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupLabel('Köşe yarıçapı'),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final e in _radii.entries)
                Column(
                  children: [
                    Container(
                      width: 128,
                      height: 84,
                      decoration: BoxDecoration(
                        color: RedoxRoles.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(e.value),
                        border: Border.all(color: RedoxAccent.ghostBorder),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.key, style: label),
                  ],
                ),
            ],
          ),
          const GroupLabel('Boşluk'),
          for (final e in _space.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 170, child: Text('${e.key} · ${e.value.round()}', style: label)),
                  Container(
                    width: e.value * 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: RedoxSeeds.amber,
                      borderRadius: BorderRadius.circular(RedoxRadius.full),
                    ),
                  ),
                ],
              ),
            ),
          Text('Çubuk uzunluğu = değer × 4', style: label),
          const GroupLabel('Derinlik ve odak'),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final e in _levels.entries)
                Column(
                  children: [
                    Container(
                      width: 150,
                      height: 90,
                      decoration: BoxDecoration(
                        color: e.value,
                        borderRadius: BorderRadius.circular(RedoxRadius.lg),
                        border: Border.fromBorderSide(RedoxElevation.restingBorder),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.key, style: label),
                  ],
                ),
              Column(
                children: [
                  Container(
                    width: 150,
                    height: 90,
                    decoration: BoxDecoration(
                      color: RedoxRoles.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(RedoxRadius.lg),
                      border: const Border.fromBorderSide(RedoxElevation.focusRing),
                      boxShadow: RedoxElevation.focusGlow,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('odak · halka + aura + ışıma', style: label),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
