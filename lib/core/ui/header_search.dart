import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
import '../theme/redox_shapes.dart';
import 'icon_action_button.dart';
import 'redox_icon.dart';

/// Başlıktaki arama: telefonda ikon düğmesi, TV/tablet/masaüstünde giriş kutusu.
/// Ayrı bir arama sekmesi yoktur. Kutu hap biçimlidir (zip'teki tasarım);
/// odakta 2px amber kenar (DESIGN.md "Input Fields").
class HeaderSearch extends StatelessWidget {
  const HeaderSearch({
    super.key,
    this.hint = 'Kanal, program veya film ara…',
    this.onOpen,
    this.onSubmitted,
  });

  final String hint;

  /// Telefonda ikon düğmesine basılınca (arama sayfası açılır).
  final VoidCallback? onOpen;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    if (metrics.formFactor == FormFactor.phone) {
      return IconActionButton(icon: RedoxIcons.search, onPressed: onOpen);
    }
    final pill = BorderRadius.circular(RedoxRadius.full);
    final t = Theme.of(context).textTheme;
    return TextField(
      onSubmitted: onSubmitted,
      style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: RedoxIcon(RedoxIcons.search, color: RedoxRoles.tertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: pill,
          borderSide: BorderSide(color: RedoxRoles.outlineVariant.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: pill,
          borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
        ),
      ),
    );
  }
}
