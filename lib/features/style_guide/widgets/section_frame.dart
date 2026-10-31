import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/section_header.dart';

/// Rehber bölümü: numaralı başlık + açıklama + içerik.
class SectionFrame extends StatelessWidget {
  const SectionFrame({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.child,
    this.accent = RedoxSeeds.crimson,
  });

  final int index;
  final String title;
  final String subtitle;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '${index.toString().padLeft(2, '0')}  $title',
            subtitle: subtitle,
            accent: accent,
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// Alt başlık (bölüm içi grup adı).
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(color: RedoxRoles.onSurface),
      ),
    );
  }
}

/// Renk değerini "#RRGGBB" olarak yazar.
String hexOf(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
