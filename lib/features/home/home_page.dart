import 'package:flutter/material.dart';

import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';
import '../../core/navigation/double_back_to_exit.dart';
import '../../core/theme/m3e_motion.dart';
import '../../core/navigation/more_sheet.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/artwork_fallback.dart';
import '../../core/ui/bottom_nav_bar.dart';
import '../../core/ui/channel_card.dart';
import '../../core/ui/media_card.dart';
import '../../core/ui/nav_rail.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/shelf.dart';
import '../../core/ui/status_badge.dart';
import '../../core/ui/story_avatar.dart';
import 'home_content.dart';
import 'widgets/continue_card.dart';
import 'widgets/hero_banner.dart';
import 'widgets/home_header.dart';
import 'widgets/radio_tile.dart';

/// Anasayfa: hikâyeler (yeni kanal ve özellikler), vitrin, son izlenen kanallar,
/// yarım kalan dizi/filmler, son dinlenen radyolar ve son izlenen filmler.
/// TV tuvali 960×540 dp (Android TV tasarım ölçüsü); içerik dikey kayar.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.content, this.previewFocus = false});

  final HomeContent content;

  /// Önizleme: vitrin düğmesini odakta çiz (gerçek odak yerine).
  final bool previewFocus;

  /// Kart genişliği: içerik genişliği n karta ve aradaki oluklara bölünür.
  /// Kesirli n (telefon) sağda bir kartın ucunu gösterir: raf kaydırılabilir.
  static double _cardWidth(double contentWidth, double perRow, double gutter) =>
      (contentWidth - gutter * (perRow - 1)) / perRow;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final m = metrics.margin;
    final gutter = metrics.gutter;
    // Telefon: ray yerine alt menü (kullanıcı isteği); içerik kenar boşluğundan başlar.
    final phone = metrics.formFactor == FormFactor.phone;
    final left = phone ? m.left : RedoxNavRail.collapsedWidth + 24;
    // Telefonda raf başına görünen kart: dört kart sığmaz, yazılar kesilir.
    double perRow(double wide, double narrow) => phone ? narrow : wide;
    // Kök sayfa: Geri bir kez uyarır, ikincisinde çıkar.
    return DoubleBackToExit(
      child: Scaffold(
        // Anasayfadayken alt menüde seçili öğe yoktur (Anasayfa logodadır).
        bottomNavigationBar: phone ? RedoxBottomBar(items: AppDestinations.phoneBar, onSelected: (_) {}) : null,
        // expand: Scaffold gövdeye gevşek kısıt verir; kaydırma görünümü içeriğe
        // büzülürse ray ekranın altına kadar uzanmaz.
        body: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth - left - m.right;
                final card = _cardWidth(width, perRow(4, 2.3), gutter);
                // Durum çubuğu ve (telefonda) alt menü payı.
                final safe = MediaQuery.paddingOf(context);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(left, m.top + safe.top, m.right, m.bottom + safe.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HomeHeader(
                        clock: content.clock,
                        profileName: content.profileName,
                        onMore: () => showMoreSheet(context, items: AppDestinations.phoneMore),
                      onRemote: () {},
                        // Zaten Anasayfadayız: başa kaydırır.
                        onHome: () =>
                            PrimaryScrollController.maybeOf(context)
                                ?.animateTo(0, duration: M3EMotion.medium4, curve: M3EMotion.standard),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          // Üste hizalı: iki satırlı etiket halkayı kaydırmaz.
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final s in content.stories)
                              StoryAvatar(
                                label: s.label,
                                seen: s.seen,
                                onPressed: () {},
                                child: ArtworkFallback(name: s.label, icon: s.icon),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      HeroBanner(hero: content.hero, primaryFocused: previewFocus ? true : null),
                      const SizedBox(height: 40),
                      Shelf(
                        header: const SectionHeader(title: 'Son izlenen kanallar', subtitle: 'Şu an yayında olanlar'),
                        children: [
                          for (final c in content.channels)
                            ChannelCard(
                              width: card,
                              channelName: c.name,
                              number: c.number,
                              programTitle: c.programTitle,
                              timeRange: c.timeRange,
                              progress: c.progress,
                              accent: c.accent,
                              badge: c.live ? const StatusBadge(label: 'CANLI', pulse: true) : null,
                              artwork: ArtworkFallback(name: c.name, icon: RedoxIcons.television),
                              onPressed: () {},
                            ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Shelf(
                        header: const SectionHeader(
                          title: 'İzlemeye devam et',
                          subtitle: 'Yarım kalan dizi ve filmler',
                          accent: RedoxSeeds.amber,
                        ),
                        children: [
                          for (final c in content.continueItems)
                            ContinueCard(item: c, width: _cardWidth(width, perRow(2, 1.15), gutter), onPressed: () {}),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Shelf(
                        header: const SectionHeader(title: 'Son dinlenen radyolar', accent: RedoxSeeds.gold),
                        children: [for (final r in content.radios) RadioTile(radio: r, width: card, onPressed: () {})],
                      ),
                      const SizedBox(height: 40),
                      Shelf(
                        header: const SectionHeader(title: 'Son izlenen filmler', accent: RedoxSeeds.amber),
                        children: [
                          for (final f in content.films)
                            MediaCard(
                              title: f.title,
                              subtitle: f.subtitle,
                              width: _cardWidth(width, perRow(5, 3.3), gutter),
                              artwork: ArtworkFallback(name: f.title, icon: RedoxIcons.film),
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            if (!phone)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: RedoxNavRail(
                  items: AppDestinations.main,
                  footer: AppDestinations.footer,
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
          ],
        ),
      ),
    );
  }
}
