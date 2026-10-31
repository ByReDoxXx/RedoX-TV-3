import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/header_search.dart';
import '../../../core/ui/icon_action_button.dart';
import '../../../core/ui/redox_icon.dart';

/// Üst şerit: logo işareti, arama (TV'de kutu), saat ve profil. Logo rayda
/// değil burada durur: 540 dp TV yüksekliğinde ray öğelerine yer kalsın diye.
/// 44 dp'de tam logonun yazısı okunmadığı için yazısız işaret kullanılır.
///
/// Arama kutusu profile kadar uzanır (kullanıcı isteği). Telefonda saat ve
/// profil sığmaz (saat zaten durum çubuğunda): arama, Kumanda ve [onMore]
/// (alt menüye sığmayan bölümler) ikon düğmeleri gösterilir.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.clock,
    required this.profileName,
    this.onMore,
    this.onHome,
    this.onRemote,
  });

  final String clock;
  final String profileName;

  /// Telefonda "Diğer" düğmesine basılınca.
  final VoidCallback? onMore;

  /// Telefonda Kumanda düğmesine basılınca (kullanıcı isteği: alt menüden
  /// aramanın yanına alındı).
  final VoidCallback? onRemote;

  /// Telefonda logoya dokununca Anasayfa'ya gidilir (alt menüde Anasayfa
  /// yoktur; kullanıcı isteği).
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final logo = SvgPicture.asset(BrandAssets.mark, width: 44, height: 44, semanticsLabel: 'RedoX TV');
    if (Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone) {
      return Row(
        children: [
          Semantics(
            button: true,
            label: 'Anasayfa',
            excludeSemantics: true,
            child: InkWell(
              onTap: onHome,
              customBorder: const CircleBorder(),
              // 48 dp dokunma hedefi (M3).
              child: Padding(padding: const EdgeInsets.all(2), child: logo),
            ),
          ),
          const Spacer(),
          // Sıra (kullanıcı isteği): Arama · Kumanda · Diğer.
          const HeaderSearch(),
          const SizedBox(width: 8),
          IconActionButton(icon: RedoxIcons.remote, onPressed: onRemote),
          const SizedBox(width: 8),
          IconActionButton(icon: RedoxIcons.more, onPressed: onMore),
        ],
      );
    }
    // Sıra: arama, profil, saat (kullanıcı isteği: saat en sağda).
    return Row(
      children: [
        logo,
        const SizedBox(width: 16),
        const Expanded(child: HeaderSearch()),
        const SizedBox(width: 16),
        _Pill(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: RedoxRoles.primaryContainer, shape: BoxShape.circle),
                child: const Center(
                  child: RedoxIcon(RedoxIcons.profile, filled: true, color: RedoxRoles.onPrimaryContainer, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Text(profileName, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RedoxIcon(RedoxIcons.clock, color: RedoxRoles.tertiary, size: 20),
              const SizedBox(width: 8),
              Text(
                clock,
                style: t.titleMedium!.copyWith(
                  color: RedoxRoles.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: RedoxType.tabular,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}
