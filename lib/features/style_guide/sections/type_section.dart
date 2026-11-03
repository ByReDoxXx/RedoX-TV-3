import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/brand_wordmark.dart';
import '../widgets/section_frame.dart';

/// 2. Yazı: Sora, DESIGN.md ölçeği.
class TypeSection extends StatelessWidget {
  const TypeSection({super.key});

  static const _sample = 'Şampiyonlar Ligi · ĞÜŞİÖÇ ğüşıöç';

  @override
  Widget build(BuildContext context) {
    final meta = Theme.of(context).textTheme.bodySmall!
        .copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular);
    return SectionFrame(
      index: 2,
      title: 'Yazı',
      subtitle: 'Sora (OFL) · ağırlık 400–800 · TV\'de en küçük yazı 16 (title-md) · rakamlar tnum.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandWordmark(fontSize: 48),
          const SizedBox(height: 20),
          for (final e in RedoxType.tokens.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: Text(
                      '${e.key}\n${_spec(e.value)}${e.value.fontSize! < RedoxType.tvMinSize ? ' · TV 16' : ''}',
                      style: meta,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _sample,
                      style: e.value.copyWith(color: RedoxRoles.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '20:45 · 001 002 011 118 · 19:30 – 21:00',
            style: RedoxType.headlineMd.copyWith(color: RedoxRoles.tertiary, fontFeatures: RedoxType.tabular),
          ),
          Text('Saat, kanal numarası, EPG saatleri: sabit genişlikli rakam', style: meta),
        ],
      ),
    );
  }

  static String _spec(TextStyle s) {
    final size = s.fontSize!;
    final line = (size * s.height!).round();
    final em = s.letterSpacing! / size;
    return '${size.round()}/$line · ${s.fontWeight!.value} · ${em.toStringAsFixed(em == 0 ? 0 : 3)}em';
  }
}
