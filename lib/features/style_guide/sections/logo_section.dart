import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/brand_wordmark.dart';
import '../widgets/section_frame.dart';

/// 7. Logo varyasyonları ve kullanım kuralları.
class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  static const _rules = [
    'Tam logo: 96 dp ve üstü (yazı ancak bu boyutta okunur).',
    'İşaret: 64 dp ve altı; başlıkta 44 dp.',
    'Metin markası: "RedoX" kızıl + "TV" altın, Sora 800.',
    'Android simgesi: işaret 66 dp güvenli alanda, siyah zemin; temalı simge için tek renk katman.',
    'Android TV afişi: 320 x 180 px, işaret + logonun kendi yazısı.',
    'Yalnızca koyu zeminde kullanılır.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final caption = t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant);
    Widget variant(String asset, double size, String label) => Column(
      children: [
        SvgPicture.asset(asset, width: size, height: size, semanticsLabel: 'RedoX TV $label'),
        const SizedBox(height: 8),
        Text(label, style: caption),
      ],
    );
    return SectionFrame(
      index: 7,
      title: 'Logo',
      subtitle: 'Kaynak: kullanıcının logosu. Varyasyonlar design/logo/logo_varyasyonlari.py ile üretilir.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          variant(BrandAssets.logo, 200, 'tam logo · 200'),
          const SizedBox(width: 32),
          variant(BrandAssets.mark, 96, 'işaret · 96'),
          const SizedBox(width: 24),
          variant(BrandAssets.mark, 44, 'işaret · 44'),
          const SizedBox(width: 40),
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
