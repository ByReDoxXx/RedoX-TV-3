import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/ui/brand_components.dart';
import '../widgets/section_frame.dart';

/// 6. Logo ve kullanım kuralları.
class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  static const _rules = [
    'Ray üstü: boğa + halka işareti 56 dp, etrafında ≥ 8 dp boşluk.',
    'Başlık: "RedoX" kızıl + "TV" altın, eğim slnt −10 (metin olarak).',
    'Açılış ekranı: tam logo SVG.',
    'Yalnızca koyu zeminde kullanılır.',
    'Açık nokta: küçük boyut için sade işaret henüz çizilmedi.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SectionFrame(
      index: 6,
      title: 'Logo',
      subtitle: 'assets/brand/redox-logo.svg (otomatik izlenmiş vektör) · wordmark metin olarak.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/brand/redox-logo.svg',
            width: 320,
            height: 320,
            semanticsLabel: 'RedoX TV logosu',
          ),
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandWordmark(fontSize: 64),
                const SizedBox(height: 24),
                for (final r in _rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('•  $r', style: t.bodyLarge!.copyWith(color: scheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
