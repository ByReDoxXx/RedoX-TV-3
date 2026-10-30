import 'package:flutter/material.dart';

import '../../../core/theme/m3e_tokens.dart';
import '../widgets/section_frame.dart';

/// 4. Şekil: M3 Expressive köşe yarıçapı ölçeği.
class ShapeSection extends StatelessWidget {
  const ShapeSection({super.key});

  static const _scale = <String, double>{
    'extraSmall 4': M3EShape.extraSmall,
    'small 8': M3EShape.small,
    'medium 12': M3EShape.medium,
    'large 16 · öğe': M3EShape.large,
    'largeIncreased 20': M3EShape.largeIncreased,
    'extraLarge 28 · kart': M3EShape.extraLarge,
    'extraLargeIncreased 32': M3EShape.extraLargeIncreased,
    'extraExtraLarge 48 · hero': M3EShape.extraExtraLarge,
    'full · çip, düğme': M3EShape.full,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return SectionFrame(
      index: 4,
      title: 'Şekil',
      subtitle: 'Köşe yarıçapı (dp). Kalın basamaklar Expressive\'e özgü. Kaynak: androidx ShapeTokens.',
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final e in _scale.entries)
            Column(
              children: [
                Container(
                  width: 168,
                  height: 112,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(e.value),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
                const SizedBox(height: 8),
                Text(e.key, style: t.labelLarge),
              ],
            ),
        ],
      ),
    );
  }
}
