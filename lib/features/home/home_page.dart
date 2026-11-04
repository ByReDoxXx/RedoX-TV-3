import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/watch_progress.dart';
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
import '../../core/ui/center_on_focus.dart';
import '../../core/ui/channel_logo.dart';
import '../../core/ui/section_header.dart';
import '../../core/ui/shelf.dart';
import 'home_content.dart';
import 'widgets/continue_card.dart';
import '../tutorial/tutorial_row.dart';
import 'widgets/live_board.dart';
import 'widgets/live_tile.dart';
import 'widgets/resume_board.dart';

/// Anasayfa, kişisel pano (B tasarımı): saate göre selam; yarıda bırakılan
/// film/bölümler ve bitmiş bölümlerin sıradakileri panoda (en yeni büyük
/// kart); kayıt yoksa pano canlıdır (büyük kartta şu an yayında olan kanal,
/// yanında sonraki iki kanal); altında "Şu an yayında" şeridi (son izlenen
/// kanallar, geçmiş boşsa ulusal kanallar; canlı panodakiler hariç).
/// Görseller yayından alınan gerçek karedir (FrameStore); uydurma içerik
/// gösterilmez. Bölüm kısayolları yalnız telefonda (TV/tablette ray var).
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
    this.resume = const [],
    this.onResume,
    this.tmdb,
  });

  /// Yarıda bırakılan filmler ve dizilerin son bölümleri (en yeni önde):
  /// "İzlemeye devam et" ve (bitmiş bölümler) "Sıradaki bölümler" rafları.
  final List<ProgressEntry> resume;
  final ValueChanged<ProgressEntry>? onResume;

  /// Devam kartlarının görseli (TMDB arka planı).
  final Tmdb? tmdb;

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

  /// Pano kartının görseli: yayın karesi; yoksa sağda kanal logosu (yazılar solda).
  Widget _boardArtwork(LiveChannel c, double width, double dpr) => _withFrames(
    () => switch (frames?.frameOf(c)) {
      final jpeg? => Image.memory(jpeg, fit: BoxFit.cover, cacheWidth: (width * dpr).round(), gaplessPlayback: true),
      null => LiveBoardLogo(channel: c),
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
    final t = Theme.of(context).textTheme;
    // Yarıda kalanlar ve bitmiş dizi bölümleri (sıradaki); bitmiş film çıkar.
    final board = [
      for (final e in resume)
        if (!e.finished || e.series) e,
    ];
    final more = board.skip(ResumeBoard.size).toList();
    // Canlı panoda (kayıt yokken) ilk kanal büyük, sonraki ikisi küçük kart;
    // şeritte tekrarlanmaz.
    final live = board.isEmpty && hero != null;
    final strip = live ? content.channels.skip(ResumeBoard.size).toList() : content.channels;
    return LayoutBuilder(
      builder: (context, box) {
        final padding = PageLayout.scrollPadding(context, metrics);
        final width = box.maxWidth - padding.horizontal;
        final card = _cardWidth(width, phone ? 2.3 : 4, gutter);
        // Şerit kartları: TV'de üçü yan yana, telefonda biri ve bir ucu.
        const stripGap = 16.0;
        final tile = _cardWidth(width, phone ? 1.4 : 3, stripGap);
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
            // Öğretici hikâyeler (kullanıcı isteği: "giren birisi uygulamayı
            // öğrensin"): her cihazda, o cihazın ekran görüntüleriyle.
            TutorialRow(kids: kids, onGo: onNavigate),
            // TV'de 540 dp'de pano ve raf ilk ekrana sığsın diye boşluk yok.
            if (metrics.formFactor != FormFactor.tv) const SizedBox(height: 12),
            Text(
              '${content.greeting}, ${content.profileName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.headlineMedium!.copyWith(color: RedoxRoles.onSurface),
            ),
            Text(
              board.isEmpty ? 'Şu an yayında olanlara göz at' : 'Kaldığın yerden devam et',
              style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (board.isNotEmpty)
              ResumeBoard(entries: board, tmdb: tmdb, onResume: onResume, previewFocus: previewFocus)
            else if (hero != null)
              LiveBoard(
                hero: hero,
                others: content.channels.where((c) => c != hero.channel).take(ResumeBoard.size - 1).toList(),
                artwork: (c, w) => _boardArtwork(c, w, dpr),
                primaryFocused: previewFocus ? true : null,
                onWatch: onWatch,
                onGuide: onGuide,
              ),
            if (strip.isNotEmpty) ...[
              // TV'de hikâye satırıyla 540 dp'ye sığsın.
              SizedBox(height: phone ? 28 : 18),
              Shelf(
                gutter: stripGap,
                header: content.fromHistory
                    ? const SectionHeader(title: 'Şu an yayında', subtitle: 'Son izlediğin kanallar')
                    : const SectionHeader(
                        title: 'Ulusal kanallar',
                        subtitle: 'İzlediğin kanallar burada görünecek',
                        accent: RedoxSeeds.amber,
                      ),
                children: [
                  for (final c in strip)
                    // D-pad odağında kart ortalanır: ekranın alt kenarında
                    // halkası kesiliyordu (gerçek TV'de görüldü).
                    CenterOnFocus(
                      child: LiveTile(
                        width: tile,
                        channelName: c.name,
                        programTitle: c.programTitle ?? 'Yayın akışı bilgisi yok',
                        progress: c.progress ?? 0,
                        accent: c.accent,
                        artwork: _artwork(c, LiveTile.thumbWidth, dpr),
                        onPressed: () => onWatch?.call(c),
                      ),
                    ),
                ],
              ),
            ],
            // Panoya sığmayan kayıtlar.
            if (more.isNotEmpty) ...[
              const SizedBox(height: 40),
              Shelf(
                header: const SectionHeader(title: 'İzlemeye devam et', subtitle: 'Diğer yarım kalanlar'),
                children: [
                  for (final e in more)
                    CenterOnFocus(
                      child: ContinueCard(entry: e, width: card, tmdb: tmdb, onPressed: () => onResume?.call(e)),
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
