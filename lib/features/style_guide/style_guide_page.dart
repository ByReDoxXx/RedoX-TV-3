import 'package:flutter/material.dart';

import '../../core/theme/redox_palette.dart';
import '../../core/theme/redox_tonal.dart';
import '../../core/ui/brand_components.dart';
import 'sections/component_section.dart';
import 'sections/icon_section.dart';
import 'sections/logo_section.dart';
import 'sections/palette_section.dart';
import 'sections/shape_section.dart';
import 'sections/type_section.dart';

/// Stil rehberi sayfası (kaydırılabilir).
class StyleGuidePage extends StatelessWidget {
  const StyleGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(child: StyleGuideContent()),
    );
  }
}

/// Rehberin içeriği; kaydırma olmadan tam boyutta çizilir (görüntü testi bunu kullanır).
class StyleGuideContent extends StatelessWidget {
  const StyleGuideContent({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      // Motif 6: zemin dikey gradyanı, üstte mavi parıltı.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.18, 1],
          colors: [
            Color(0x801E3755), // backgroundGlow %50
            RedoxDarkRoles.surface,
            RedoxPalette.backgroundDeep,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(72, 64, 72, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const BrandWordmark(fontSize: 48),
                const SizedBox(width: 20),
                Text('3.0 · Stil Rehberi', style: t.headlineMedium!.copyWith(color: scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Material 3 Expressive + logodan tasarım dili · tüm değerler uygulamanın kendi belirteçlerinden çizilir',
              style: t.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 48),
            const PaletteSection(),
            const TypeSection(),
            const IconSection(),
            const ShapeSection(),
            const ComponentSection(),
            const LogoSection(),
          ],
        ),
      ),
    );
  }
}
