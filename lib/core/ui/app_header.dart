import 'package:flutter/material.dart';

import '../brand/brand_assets.dart';
import '../layout/form_factor.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_type.dart';
import 'focus_glow.dart';
import 'header_search.dart';
import 'icon_action_button.dart';
import 'redox_icon.dart';

/// Bölüm sayfalarının üst şeridi: logo işareti, arama (TV'de kutu), saat ve
/// profil. Logo rayda değil burada durur: 540 dp TV yüksekliğinde ray
/// öğelerine yer kalsın diye.
/// 44 dp'de tam logonun yazısı okunmadığı için yazısız işaret kullanılır.
///
/// Arama kutusu profile kadar uzanır (kullanıcı isteği). Telefonda saat ve
/// profil sığmaz (saat zaten durum çubuğunda): arama ve [onMore]
/// (alt menüye sığmayan bölümler) ikon düğmeleri gösterilir.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.clock,
    required this.profileName,
    this.onMore,
    this.onHome,
    this.onProfile,
    this.kids = false,
  });

  /// Logo işareti: TV/tablet 44 dp. Telefonda 56 dp (kullanıcı isteği:
  /// biraz büyüsün); başlıkta yer var, dokunma hedefi de 48'i aşar.
  static const double logoSize = 44;
  static const double phoneLogoSize = 56;

  final String clock;
  final String profileName;

  /// Telefonda "Diğer" düğmesine basılınca.
  final VoidCallback? onMore;

  /// Telefonda logoya dokununca Anasayfa'ya gidilir (alt menüde Anasayfa
  /// yoktur; kullanıcı isteği).
  final VoidCallback? onHome;

  /// Profil hapına basılınca: "Kim izliyor?" ekranı (profil değiştir).
  final VoidCallback? onProfile;

  /// Çocuk profili: hapta çocuk ikonu.
  final bool kids;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    // Bitmap işaret: SVG her karede ~2300 yolu yeniden çizerdi (kaydırırken
    // zayıf TV GPU'sunda takılma).
    final logo = Image.asset(
      BrandAssets.markPng,
      width: phone ? phoneLogoSize : logoSize,
      height: phone ? phoneLogoSize : logoSize,
      semanticLabel: 'RedoX TV',
      filterQuality: FilterQuality.medium,
    );
    if (phone) {
      return Row(
        children: [
          Semantics(
            button: true,
            label: 'Anasayfa',
            excludeSemantics: true,
            child: InkWell(onTap: onHome, customBorder: const CircleBorder(), child: logo),
          ),
          const Spacer(),
          // Sıra: Arama · Diğer. Kumanda "Diğer" sayfasındadır (kullanıcı
          // isteği: başlıkta göze batıyordu).
          const HeaderSearch(),
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
        FocusGlow(
          borderRadius: BorderRadius.circular(RedoxRadius.full),
          builder: (context, active) => Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(RedoxRadius.full),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: Semantics(
                button: true,
                label: 'Profil değiştir',
                child: _Pill(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: RedoxRoles.primaryContainer, shape: BoxShape.circle),
                        child: Center(
                          child: RedoxIcon(
                            kids ? RedoxIcons.kids : RedoxIcons.profile,
                            filled: true,
                            color: RedoxRoles.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(profileName, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
                    ],
                  ),
                ),
              ),
            ),
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
