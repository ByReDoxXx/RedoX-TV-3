import 'package:flutter/material.dart';

import '../../core/layout/page_layout.dart';
import '../../core/navigation/destinations.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/redox_icon.dart';

/// Henüz yazılmamış bölüm: ikon, ad ve "yakında" notu. Gezinme her bölümde
/// çalışsın, boş ekran kalmasın diye.
class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: PageLayout.scrollPadding(context, metrics),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RedoxIcon(section.icon, color: RedoxRoles.onSurfaceVariant, size: 48),
            const SizedBox(height: 16),
            Text(section.label, style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
            const SizedBox(height: 4),
            Text('Bu bölüm yakında.', style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
