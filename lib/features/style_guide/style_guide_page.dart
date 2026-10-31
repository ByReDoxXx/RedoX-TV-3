import 'package:flutter/material.dart';

import '../../core/theme/redox_colors.dart';
import '../../core/ui/brand_wordmark.dart';
import 'sections/component_section.dart';
import 'sections/icon_section.dart';
import 'sections/logo_section.dart';
import 'sections/palette_section.dart';
import 'sections/shape_section.dart';
import 'sections/surfaces_section.dart';
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
    return ColoredBox(
      color: RedoxRoles.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 40, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const BrandWordmark(fontSize: 40),
                const SizedBox(width: 16),
                Text('3.0 · Stil Rehberi', style: t.headlineMedium!.copyWith(color: RedoxRoles.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'RedoX TV Expressive (DESIGN.md) · Material 3 Expressive · TV ölçeğinde (960 dp genişlik) çizilir',
              style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            const PaletteSection(),
            const TypeSection(),
            const IconSection(),
            const ShapeSection(),
            const ComponentSection(),
            const SurfacesSection(),
            const LogoSection(),
          ],
        ),
      ),
    );
  }
}
