import 'package:flutter/material.dart';

import '../../../core/navigation/destinations.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/channel_card.dart';
import '../../../core/ui/media_card.dart';
import '../../../core/ui/nav_rail.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/status_badge.dart';
import '../../../core/ui/story_avatar.dart';
import '../widgets/section_frame.dart';

/// 6. Kartlar, hikâyeler ve gezinme rayı; boşta ve odakta.
class SurfacesSection extends StatelessWidget {
  const SurfacesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant);
    return SectionFrame(
      index: 6,
      title: 'Kartlar ve gezinme',
      subtitle: 'Kart odakta TV\'de 1.08 büyür; oluk 48 dp bu büyüme için yer bırakır.',
      accent: RedoxSeeds.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupLabel('Kanal kartı · medya kartı (boşta / odakta)'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChannelCard(
                  channelName: 'ÖRNEK KANAL',
                  programTitle: 'Akşam Haberleri',
                  timeRange: '19:00 – 20:00',
                  genre: 'Haber',
                  number: 2,
                  progress: 0.35,
                  accent: CardAccent.amber,
                  artwork: ArtworkFallback(name: 'Örnek Kanal', icon: RedoxIcons.television),
                ),
                SizedBox(width: 48),
                ChannelCard(
                  channelName: 'ÖRNEK SPOR',
                  programTitle: 'Canlı Maç',
                  timeRange: '20:45 – 22:45',
                  genre: 'Spor',
                  number: 104,
                  progress: 0.6,
                  badge: StatusBadge(label: 'CANLI', pulse: true),
                  artwork: ArtworkFallback(name: 'Örnek Spor', icon: RedoxIcons.television),
                  focused: true,
                ),
                SizedBox(width: 48),
                MediaCard(
                  title: 'Örnek Film',
                  subtitle: '2024 · 2 sa 8 dk',
                  width: 132,
                  badge: StatusBadge(label: '4K', tone: BadgeTone.gold),
                  artwork: ArtworkFallback(name: 'Örnek Film', icon: RedoxIcons.film),
                ),
                SizedBox(width: 48),
                MediaCard(
                  title: 'Örnek Film',
                  subtitle: '2024 · 2 sa 8 dk',
                  width: 132,
                  artwork: ArtworkFallback(name: 'Örnek Film', icon: RedoxIcons.film),
                  focused: true,
                ),
              ],
            ),
          ),
          const GroupLabel('Hikâye halkası · görülmemiş / görülmüş / odakta'),
          const Row(
            children: [
              StoryAvatar(label: 'Yeni kanal', child: ArtworkFallback(name: 'Yeni Kanal', icon: RedoxIcons.television)),
              SizedBox(width: 16),
              StoryAvatar(label: 'Radyo', seen: true, child: ArtworkFallback(name: 'Radyo', icon: RedoxIcons.radio)),
              SizedBox(width: 16),
              StoryAvatar(label: 'Özellik', focused: true, child: ArtworkFallback(name: 'Bölünmüş Ekran', icon: RedoxIcons.splitScreen)),
            ],
          ),
          const GroupLabel('Gezinme rayı (M3 Expressive) · daralmış / açık'),
          SizedBox(
            height: 560,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const RedoxNavRail(
                  items: AppDestinations.main,
                  footer: AppDestinations.footer,
                  selectedIndex: 0,
                  expanded: false,
                ),
                const SizedBox(width: 48),
                const RedoxNavRail(
                  items: AppDestinations.main,
                  footer: AppDestinations.footer,
                  selectedIndex: 0,
                  expanded: true,
                  focusedIndex: 1,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'M3 Expressive rayı. Daralmış: 96 dp, surface, 56 x 32 hap gösterge. '
                    'Açık: 256 dp modal ray, surfaceContainer, 16 dp uç köşe, seviye 2 gölge; '
                    'öğe 56 dp, ikon + etiket. Seçili: secondaryContainer gösterge. '
                    'Odak: halka + aura. Açık ray içeriğin üstüne biner.',
                    style: label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
