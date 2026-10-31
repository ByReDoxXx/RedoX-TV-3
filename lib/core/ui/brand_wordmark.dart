import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_type.dart';

/// Metin olarak marka adı: "RedoX" kızıl + " TV" altın, Sora 800.
/// Kızıl yalnızca büyük yazıda kullanılır (zeminde 4,17:1; büyük yazı eşiği 3:1).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: RedoxType.family,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.02 * fontSize,
      height: 1,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'RedoX', style: base.copyWith(color: RedoxSeeds.crimson)),
          TextSpan(text: ' TV', style: base.copyWith(color: RedoxSeeds.gold)),
        ],
      ),
      semanticsLabel: 'RedoX TV',
    );
  }
}
