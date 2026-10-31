import 'package:flutter/material.dart';

import '../../core/navigation/destinations.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/artwork_fallback.dart';
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
  static double _cardWidth(double contentWidth, int perRow, double gutter) =>
      (contentWidth - gutter * (perRow - 1)) / perRow;

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final m = metrics.margin;
    final gutter = metrics.gutter;
    const left = RedoxNavRail.collapsedWidth + 24;
    return Scaffold(
      // expand: Scaffold gövdeye gevşek kısıt verir; kaydırma görünümü içeriğe
      // büzülürse ray ekranın altına kadar uzanmaz.
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth - left - m.right;
              final card = _cardWidth(width, 4, gutter);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(left, m.top, m.right, m.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(clock: content.clock, profileName: content.profileName),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
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
                    const SizedBox(height: 24),
                    HeroBanner(hero: content.hero, primaryFocused: previewFocus ? true : null),
                    const SizedBox(height: 40),
                    Shelf(
                      header: const SectionHeader(
                        title: 'Son izlenen kanallar',
                        subtitle: 'Şu an yayında olanlar',
                      ),
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
                          ContinueCard(item: c, width: _cardWidth(width, 2, gutter), onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Shelf(
                      header: const SectionHeader(
                        title: 'Son dinlenen radyolar',
                        accent: RedoxSeeds.gold,
                      ),
                      children: [
                        for (final r in content.radios) RadioTile(radio: r, width: card, onPressed: () {}),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Shelf(
                      header: const SectionHeader(
                        title: 'Son izlenen filmler',
                        accent: RedoxSeeds.amber,
                      ),
                      children: [
                        for (final f in content.films)
                          MediaCard(
                            title: f.title,
                            subtitle: f.subtitle,
                            width: _cardWidth(width, 5, gutter),
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
    );
  }
}
