import 'package:flutter/material.dart';

import '../theme/redox_shapes.dart';

/// Kumanda tuş ipucu ("OK"). Renkli tuş (kırmızı/yeşil/sarı/mavi) ipucu
/// kullanılmaz: Chromecast 4K gibi kumandalarda bu tuşlar yoktur.
class KeyHint extends StatelessWidget {
  const KeyHint(this.label, {super.key, required this.color});

  final String label;

  /// Bulunduğu yüzeyin yazı rengi; zemin bu rengin %20'sidir.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(RedoxRadius.xs),
      ),
      child: Text(
        label,
        style: style.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
