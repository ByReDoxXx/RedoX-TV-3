import 'package:flutter/material.dart';

import '../../../core/theme/redox_type.dart';
import '../../../core/ui/brand_components.dart';

/// Rehber bölümü: numara + başlık + açıklama + içerik.
class SectionFrame extends StatelessWidget {
  const SectionFrame({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int index;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index.toString().padLeft(2, '0')}  $title',
            style: t.headlineSmall!.copyWith(
              fontWeight: FontWeight.w500,
              fontVariations: RedoxType.brandSlant,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: t.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const FlareDivider(),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// Renk değerini "#RRGGBB" olarak yazar.
String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
