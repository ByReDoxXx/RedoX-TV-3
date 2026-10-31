import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';

/// İlerleme çubuğu. İz, en alt kap (obsidyen) rengindedir: kızıl dolgu en
/// yüksek kap izinde yalnızca 2,65:1 verir, obsidyende 4,17:1 (metin dışı
/// eşik 3:1; redox_contrast_test.dart).
class RedoxProgressBar extends StatelessWidget {
  const RedoxProgressBar({
    super.key,
    required this.value,
    this.color = RedoxSeeds.amber,
    this.thermal = false,
    this.height = 6,
  });

  /// 0…1.
  final double value;

  /// Tek renk dolgu (varsayılan amber: "progress completion").
  final Color color;

  /// true: kızıl → amber → altın ısıl degrade.
  final bool thermal;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RedoxRadius.full),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: RedoxRoles.surfaceContainerLowest),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thermal ? null : color,
                  gradient: thermal ? const LinearGradient(colors: RedoxAccent.thermal) : null,
                  borderRadius: BorderRadius.circular(RedoxRadius.full),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
