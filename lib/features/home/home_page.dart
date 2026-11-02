import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/layout/page_layout.dart';
import '../../core/navigation/destinations.dart';
import '../../core/playback/frame_grabber.dart';
import '../../core/navigation/more_sheet.dart';
import '../../core/theme/m3e_motion.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/hiding_header.dart';
import '../../core/ui/app_header.dart';
import '../../core/ui/artwork_fallback.dart';
import '../../core/ui/center_on_focus.dart';
import '../../core/ui/channel_card.dart';
import '../../core/ui/channel_logo.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/shelf.dart';
import '../../core/ui/story_avatar.dart';
import 'home_content.dart';
import 'widgets/hero_banner.dart';

/// Anasayfa: bölüm kısayolları, vitrin (şu an yayında olan kanal) ve son
/// izlenen kanallar (geçmiş boşsa ulusal kanallar); kart ve vitrin görseli
/// yayından alınan gerçek karedir (FrameStore). Dizi, film ve radyo rafları
/// o bölümler yazılınca gelecek; uydurma içerik gösterilmez.
/// TV tuvali 960×540 dp (Android TV tasarım ölçüsü); içerik dikey kayar.
/// Ray, alt menü ve Geri kök kabuktadır (RootShell).
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.content,
    this.previewFocus = false,
    this.onNavigate,
    this.onWatch,
    this.onGuide,
    this.frames,
    this.onMore,
    this.onProfile,
    this.kids = false,
  });

  /// Telefonda "Diğer" düğmesi; null ise bölümlerin "Diğer" sayfası.
  final VoidCallback? onMore;

  /// Başlıktaki profil hapı (profil değiştir).
  final VoidCallback? onProfile;

  /// Çocuk profili (başlıkta çocuk ikonu).
  final bool kids;

  final HomeContent content;

  /// Kanalların yayından alınmış kareleri (kart ve vitrin görseli); yoksa logo.
  final FrameStore? frames;

  /// Önizleme: vitrin düğmesini odakta çiz (gerçek odak yerine).
  final bool previewFocus;

  /// Kısayol halkası ya da "Diğer" sayfasından bir bölüm seçilince.
  final ValueChanged<AppSection>? onNavigate;

  /// Kanal tam ekran izlenmek istenince (vitrin, raf).
  final ValueChanged<LiveChannel>? onWatch;

  /// "Yayın akışı": Televizyon sayfasının EPG çizelgesi.
  final VoidCallback? onGuide;

  /// Kart genişliği: içerik genişliği n karta ve aradaki oluklara bölünür.
  /// Kesirli n (telefon) sağda bir kartın ucunu gösterir: raf kaydırılabilir.
  static double _cardWidth(double contentWidth, double perRow, double gutter) =>
      (contentWidth - gutter * (perRow - 1)) / perRow;

  /// Kare deposunu dinleyen parça: kare gelince yalnız o görsel yeniden
  /// kurulur (bütün sayfa değil; zayıf TV işlemcisi).
  Widget _withFrames(Widget Function() builder) => switch (frames) {
    final f? => ListenableBuilder(listenable: f, builder: (context, _) => builder()),
    null => builder(),
  };

  /// Kartın görseli: yayın karesi; yoksa kanal logosu.
  Widget _artwork(LiveChannel c, double width, double dpr) => _withFrames(
    () => switch (frames?.frameOf(c)) {
      final jpeg? => Image.memory(
        jpeg,
        fit: BoxFit.cover,
        // Tam boy kare (1080p) zayıf TV belleğinde kart boyuna küçültülerek çözülür.
        cacheWidth: (width * dpr).round(),
        gaplessPlayback: true,
      ),
      null => ChannelLogo(name: c.name, logoUrl: c.logoUrl),
    },
  );

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final gutter = metrics.gutter;
    // Telefonda raf başına görünen kart: dört kart sığmaz, yazılar kesilir.
    final phone = metrics.formFactor == FormFactor.phone;
    final hero = content.hero;
    return LayoutBuilder(
      builder: (context, box) {
        final padding = PageLayout.scrollPadding(context, metrics);
        final width = box.maxWidth - padding.horizontal;
        final card = _cardWidth(width, phone ? 2.3 : 4, gutter);
        final header = AppHeader(
          clock: content.clock,
          profileName: content.profileName,
          onProfile: onProfile,
          kids: kids,
          onMore:
              onMore ??
              () => showMoreSheet(
                context,
                items: AppDestinations.phoneMore,
                onSelected: (i) => onNavigate?.call(AppDestinations.phoneMoreSections[i]),
              ),
          // Zaten Anasayfadayız: başa kaydırır.
          onHome: () =>
              PrimaryScrollController.maybeOf(context)
                  ?.animateTo(0, duration: M3EMotion.medium4, curve: M3EMotion.standard),
        );
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                // Üste hizalı: iki satırlı etiket halkayı kaydırmaz.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in content.shortcuts)
                    StoryAvatar(
                      // Kısa ad: "Televizyon" halkanın altına sığmıyor ("TV").
                      label: s.shortLabel,
                      onPressed: () => onNavigate?.call(s),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ArtworkFallback(name: s.label, showInitials: false),
                          Center(child: RedoxIcon(s.icon, size: 30, color: RedoxRoles.onSurface)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (hero != null)
              _withFrames(
                () => HeroBanner(
                  hero: hero,
                  frame: frames?.frameOf(hero.channel),
                  primaryFocused: previewFocus ? true : null,
                  onWatch: () => onWatch?.call(hero.channel),
                  onGuide: onGuide,
                ),
              ),
            if (content.channels.isNotEmpty) ...[
              const SizedBox(height: 40),
              Shelf(
                header: content.fromHistory
                    ? const SectionHeader(title: 'Son izlenen kanallar', subtitle: 'Şu an yayında olanlar')
                    : const SectionHeader(
                        title: 'Ulusal kanallar',
                        subtitle: 'İzlediğin kanallar burada görünecek',
                        accent: RedoxSeeds.amber,
                      ),
                children: [
                  for (final c in content.channels)
                    // D-pad odağında kart ortalanır: ekranın alt kenarında
                    // halkası kesiliyordu (gerçek TV'de görüldü).
                    CenterOnFocus(
                      child: ChannelCard(
                        width: card,
                        channelName: c.name,
                        number: c.number,
                        programTitle: c.programTitle ?? 'Yayın akışı bilgisi yok',
                        timeRange: c.timeRange ?? c.category,
                        genre: c.genre,
                        progress: c.progress ?? 0,
                        accent: c.accent,
                        artwork: _artwork(c, card, dpr),
                        onPressed: () => onWatch?.call(c),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
        // Telefonda başlık üstte (kullanıcı isteği: başa dönmek gerekmesin);
        // aşağı kaydırınca gizlenir, yukarı kaydırınca geri gelir. TV/tablette
        // içerikle kayar (540 dp'de yer kazanmak için).
        if (phone) {
          return Padding(
            // Telefonda başlık durum çubuğuna (saatin altına) yaslı (kullanıcı isteği).
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: HidingHeader(
              header: Padding(
                padding: EdgeInsets.only(left: padding.left, right: padding.right),
                child: header,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right, padding.bottom),
                child: body,
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, const SizedBox(height: 12), body],
          ),
        );
      },
    );
  }
}
