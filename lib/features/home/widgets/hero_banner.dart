import 'package:flutter/material.dart';

import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';
import '../home_content.dart';

/// Vitrin: şu an yayında olan öne çıkan içerik. rounded-xl, arkada kromatik
/// ışık (DESIGN.md "Chromatic Backlight Flares"; zip'teki tasarımın hero hâlesi).
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.hero, this.primaryFocused});

  final HomeHero hero;

  /// Önizleme: birincil düğmeyi odakta göster.
  final bool? primaryFocused;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.xl);
    // Telefon: kumanda yok ("OK" ipucu anlamsız); düğmeler tek satırda,
    // ikincil düğmeler yalnız ikon (kullanıcı isteği: yan yana ve küçük).
    final phone = Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.phone;
    final primary = PrimaryButton(
      label: 'Canlı yayına gir',
      icon: RedoxIcons.play,
      keyHint: phone ? null : 'OK',
      onPressed: () {},
      focused: primaryFocused,
      autofocus: primaryFocused == null,
    );
    final multi = GlassButton(
      label: 'Çoklu ekrana ekle',
      icon: RedoxIcons.splitScreen,
      iconOnly: phone,
      onPressed: () {},
    );
    final guide = GlassButton(label: 'Yayın akışı', icon: RedoxIcons.clock, iconOnly: phone, onPressed: () {});
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: RedoxSeeds.crimson.withValues(alpha: 0.28),
            offset: const Offset(-8, 0),
            blurRadius: cssBlur(48),
          ),
          BoxShadow(
            color: RedoxSeeds.amber.withValues(alpha: 0.16),
            offset: const Offset(12, 8),
            blurRadius: cssBlur(64),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: ArtworkFallback(name: hero.channelName, showInitials: false),
            ),
            // Okunurluk: alttan ve soldan obsidyen perde.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [RedoxSeeds.obsidian, Color(0xB3000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    stops: [0, 0.45, 0.8],
                    colors: [RedoxSeeds.obsidian, Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            // Vitrin tam genişliktir; içerik (Wrap) genişliği belirlemez.
            Container(
              width: double.infinity,
              // Telefonda M3 kart iç boşluğu (16–20 dp); düğmeler satıra sığsın.
              padding: phone ? const EdgeInsets.all(20) : const EdgeInsets.fromLTRB(28, 22, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const StatusBadge(label: 'CANLI YAYIN', pulse: true),
                      _InfoPill(
                        text: '${hero.channelName} · Kanal ${hero.number}',
                        color: RedoxRoles.tertiary,
                      ),
                      _InfoPill(text: hero.tech, color: RedoxRoles.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(hero.title, style: t.headlineLarge!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 4),
                  Text(hero.subtitle, style: t.bodyLarge!.copyWith(color: RedoxRoles.secondary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 460,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RedoxRoles.surfaceContainerHigh.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(RedoxRadius.lg),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Dar ekranda evre metni kısalır, saatle çakışmaz.
                              Expanded(
                                child: Text(
                                  hero.phase,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelMedium!.copyWith(color: RedoxRoles.onSurface),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hero.clock,
                                style: t.labelMedium!.copyWith(
                                  color: RedoxRoles.onSurfaceVariant,
                                  fontFeatures: RedoxType.tabular,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RedoxProgressBar(value: hero.progress, thermal: true, height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (phone)
                    Row(
                      children: [
                        // 360 dp ekranda birincil düğme sığmazsa orantılı küçülür.
                        Flexible(
                          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: primary),
                        ),
                        const SizedBox(width: 12),
                        multi,
                        const SizedBox(width: 8),
                        guide,
                      ],
                    )
                  else
                    // Dar tablet/masaüstü penceresinde düğmeler alt satıra iner.
                    Wrap(spacing: 16, runSpacing: 12, children: [primary, multi, guide]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color, fontFeatures: RedoxType.tabular),
      ),
    );
  }
}
