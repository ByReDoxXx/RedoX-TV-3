import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/artwork_fallback.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/story_avatar.dart';
import 'tutorial_stories.dart';
import 'tutorial_viewer.dart';

/// Anasayfa'nın hikâye satırı: her bölümün öğretici hikâyesi (Anasayfa, TV,
/// Radyo, Film…). İzlenmemiş halka ısıl degradeli, izlenen soluk. Halka
/// hikâyeyi o bölümden açar; hikâye sıradaki bölümlerle sürer.
class TutorialRow extends StatelessWidget {
  const TutorialRow({super.key, this.kids = false, this.onGo});

  /// Çocuk profili: yalnız Anasayfa ve Televizyon.
  final bool kids;

  /// "Bölüme git".
  final ValueChanged<AppSection>? onGo;

  @override
  Widget build(BuildContext context) {
    final tv = Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.tv;
    final stories = TutorialStories.forProfile(kids: kids);
    return ValueListenableBuilder(
      valueListenable: TutorialSeen.instance,
      builder: (context, seen, _) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          // Üste hizalı: iki satırlı etiket halkayı kaydırmaz.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, s) in stories.indexed)
              StoryAvatar(
                // Kısa ad: "Televizyon" halkanın altına sığmıyor ("TV").
                label: s.section.shortLabel,
                seen: seen.contains(s.section),
                // TV'de 540 dp'de pano ve raf ilk ekrana sığsın.
                diameter: tv ? 48 : 72,
                onPressed: () => unawaited(showTutorial(context, stories: stories, start: i, onGo: onGo)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtworkFallback(name: s.section.label, showInitials: false),
                    Center(
                      child: RedoxIcon(s.section.icon, size: tv ? 22 : 30, color: RedoxRoles.onSurface),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
