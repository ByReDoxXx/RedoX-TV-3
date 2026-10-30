import 'package:flutter/material.dart';

import '../../../core/theme/m3e_tokens.dart';
import '../../../core/theme/redox_palette.dart';
import '../../../core/ui/redox_icon.dart';
import '../widgets/section_frame.dart';

/// 3. İkon seti: boş (boşta) ve dolu (seçili) hâller.
class IconSection extends StatelessWidget {
  const IconSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SectionFrame(
      index: 3,
      title: 'İkon seti',
      subtitle: 'Material Symbols Outlined (Apache-2.0) · SVG · boşta gri, seçili dolu kızıl, odakta altın.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final icon in RedoxIcons.values)
            Container(
              width: 196,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(M3EShape.large),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RedoxIcon(icon, color: scheme.onSurfaceVariant, size: 32),
                      const SizedBox(width: 20),
                      RedoxIcon(icon, filled: true, color: RedoxPalette.red, size: 32),
                      const SizedBox(width: 20),
                      RedoxIcon(icon, filled: true, color: RedoxPalette.goldBright, size: 32),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(icon.label, style: t.labelLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
