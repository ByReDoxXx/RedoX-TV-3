import 'package:flutter/material.dart';

import '../../../core/theme/m3e_tokens.dart';
import '../../../core/theme/redox_palette.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/brand_components.dart';
import '../widgets/section_frame.dart';

/// 2. Yazı tipi: Google Sans Flex, baz ve vurgulu ölçek.
class TypeSection extends StatelessWidget {
  const TypeSection({super.key});

  static const _sample = 'Kızıl Halka · ĞÜŞİÖÇ ğüşıöç';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = M3EType.baseline.apply(fontFamily: RedoxType.family);
    final emph = M3EType.emphasized.apply(fontFamily: RedoxType.family);
    final rows = <String, (TextStyle?, TextStyle?)>{
      'displayMedium': (base.displayMedium, emph.displayMedium),
      'headlineLarge': (base.headlineLarge, emph.headlineLarge),
      'headlineSmall': (base.headlineSmall, emph.headlineSmall),
      'titleLarge': (base.titleLarge, emph.titleLarge),
      'titleMedium': (base.titleMedium, emph.titleMedium),
      'labelLarge': (base.labelLarge, emph.labelLarge),
      'bodyLarge': (base.bodyLarge, emph.bodyLarge),
      'bodyMedium': (base.bodyMedium, emph.bodyMedium),
    };
    final meta = Theme.of(context).textTheme.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
          fontFeatures: M3EType.tabularFigures,
        );

    return SectionFrame(
      index: 2,
      title: 'Yazı tipi',
      subtitle: 'Google Sans Flex (OFL) · Türkçe karakterler ve sabit genişlikli rakam doğrulandı · monospace yok.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandWordmark(fontSize: 56),
          const SizedBox(height: 8),
          Text('Marka anı: eğim slnt −10 · ağırlık 800', style: meta),
          const SizedBox(height: 28),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: Text(
                      '${e.key}\n${e.value.$1!.fontSize!.round()}/${(e.value.$1!.fontSize! * e.value.$1!.height!).round()}',
                      style: meta,
                    ),
                  ),
                  Expanded(child: Text(_sample, style: e.value.$1!.copyWith(color: scheme.onSurface), maxLines: 1, overflow: TextOverflow.clip)),
                  const SizedBox(width: 24),
                  Expanded(child: Text(_sample, style: e.value.$2!.copyWith(color: scheme.onSurface), maxLines: 1, overflow: TextOverflow.clip)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '20:45 · 001 002 011 118 · 19:30–21:00',
            style: base.headlineSmall!.copyWith(
              color: RedoxPalette.gold,
              fontFeatures: M3EType.tabularFigures,
            ),
          ),
          Text('Saat, kanal numarası, EPG saatleri: tabular rakam', style: meta),
        ],
      ),
    );
  }
}
