import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/redox_icon.dart';
import '../widgets/section_frame.dart';

/// 3. İkon seti: boşta, seçili ve odakta hâller.
class IconSection extends StatelessWidget {
  const IconSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionFrame(
      index: 3,
      title: 'İkon',
      subtitle: 'Material Symbols Outlined (Apache-2.0) · SVG · boşta gri, seçili dolu kızıl, odakta dolu amber.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final icon in RedoxIcons.values)
            Container(
              width: 140,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: RedoxRoles.surfaceContainer,
                borderRadius: BorderRadius.circular(RedoxRadius.lg),
                border: Border.all(color: RedoxAccent.ghostBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RedoxIcon(icon, color: RedoxRoles.onSurfaceVariant),
                      const SizedBox(width: 14),
                      RedoxIcon(icon, filled: true, color: RedoxSeeds.crimson),
                      const SizedBox(width: 14),
                      RedoxIcon(icon, filled: true, color: RedoxSeeds.amber),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(icon.label, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurface)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
