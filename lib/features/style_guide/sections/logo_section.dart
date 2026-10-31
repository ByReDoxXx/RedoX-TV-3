import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/brand_wordmark.dart';
import '../widgets/section_frame.dart';

/// 7. Logo ve kullanım kuralları.
class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  static const _rules = [
    'Ray üstü: logo 48 dp, etrafında >= 8 dp boşluk.',
    'Metin markası: "RedoX" kızıl + "TV" altın, Sora 800.',
    'Açılış ekranı: tam logo SVG.',
    'Yalnızca koyu zeminde kullanılır.',
    'Açık nokta: küçük boyut için sade işaret henüz çizilmedi.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SectionFrame(
      index: 7,
      title: 'Logo',
      subtitle: 'assets/brand/redox-logo.svg (otomatik izlenmiş vektör) · marka adı metin olarak.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/brand/redox-logo.svg',
            width: 220,
            height: 220,
            semanticsLabel: 'RedoX TV logosu',
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandWordmark(fontSize: 48),
                const SizedBox(height: 20),
                for (final r in _rules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('•  $r', style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
