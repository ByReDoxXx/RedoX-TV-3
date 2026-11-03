import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';

/// Bölüm başlığı: solda dikey vurgu çubuğu, başlık, isteğe bağlı alt başlık
/// ve sağda eylem.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.accent = RedoxSeeds.crimson, this.trailing});

  final String title;
  final String? subtitle;

  /// Vurgu çubuğu rengi (metin değil; zeminde >= 3:1).
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 28,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(RedoxRadius.full)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
              if (subtitle != null) Text(subtitle!, style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
