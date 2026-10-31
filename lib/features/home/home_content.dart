import '../../core/content/epg_program.dart';
import '../../core/content/live_channel.dart';
import '../../core/navigation/destinations.dart';

// Anasayfa'nın gösterim modelleri: kanal listesinden ve izleme geçmişinden
// türer. Burada ağ veya depolama API'si yoktur.

/// Vitrin: şu an yayında olan bir kanal (son izlenen ya da ilk ulusal kanal).
class HomeHero {
  const HomeHero({
    required this.channel,
    required this.title,
    required this.subtitle,
    required this.phase,
    required this.clock,
    required this.progress,
    required this.tech,
  });

  /// Yayın akışından kanalın şimdiki programıyla.
  factory HomeHero.of(LiveChannel c, {int? nowMinute}) {
    final range = c.timeRange;
    final end = range == null ? null : EpgProgram.parseClock(range.split('–').last);
    final left = end == null || nowMinute == null ? null : (end - nowMinute) % (24 * 60);
    return HomeHero(
      channel: c,
      title: c.programTitle ?? c.name,
      subtitle: [c.category, ?c.genre, 'Canlı'].join(' · '),
      phase: range ?? 'Yayın akışı bilgisi yok',
      clock: left == null || left == 0 ? '' : '$left dk kaldı',
      progress: c.progress ?? 0,
      tech: '${c.streams.length} akış',
    );
  }

  final LiveChannel channel;
  String get channelName => channel.name;
  int get number => channel.number;

  /// Şimdiki program; yayın akışı yoksa kanal adı.
  final String title;

  /// Örn. "Ulusal · Dizi · Canlı".
  final String subtitle;

  /// Örn. "20:00 – 22:30".
  final String phase;

  /// Örn. "35 dk kaldı".
  final String clock;
  final double progress;

  /// Teknik bilgi rozeti, örn. "12 akış".
  final String tech;
}

class HomeContent {
  const HomeContent({
    required this.profileName,
    required this.clock,
    required this.hero,
    required this.shortcuts,
    required this.channels,
    required this.fromHistory,
  });

  /// Kanal listesinden: geçmişte izlenen kanallar (sırayla) ve vitrinde en
  /// son izlenen. Geçmiş boşsa ulusal kanallar ve ilk ulusal kanal; ulusal
  /// kanal yoksa (çocuk profili) listenin başı. Çocuk profilinde kısayol
  /// yalnız Televizyon'dur.
  factory HomeContent.from({
    required List<LiveChannel> channels,
    required List<int> recent,
    required String clock,
    int? nowMinute,
    String profileName = 'Profil 1',
    bool kids = false,
  }) {
    final byNumber = {for (final c in channels) c.number: c};
    final watched = [for (final n in recent) ?byNumber[n]];
    final national = channels.where((c) => c.category == 'Ulusal').take(shelfSize).toList();
    final fallback = national.isNotEmpty ? national : channels.take(shelfSize).toList();
    final shelf = watched.isNotEmpty ? watched.take(shelfSize).toList() : fallback;
    final featured = shelf.firstOrNull ?? channels.firstOrNull;
    return HomeContent(
      profileName: profileName,
      clock: clock,
      hero: featured == null ? null : HomeHero.of(featured, nowMinute: nowMinute ?? EpgProgram.parseClock(clock)),
      shortcuts: kids ? kidsShortcutSections : shortcutSections,
      channels: shelf,
      fromHistory: watched.isNotEmpty,
    );
  }

  /// Rafta gösterilen en çok kanal.
  static const shelfSize = 8;

  /// Kısayol halkaları: uygulamanın bölümleri (telefonda ray olmadığından
  /// asıl gezinme yolu; TV'de hızlı erişim).
  static const shortcutSections = [
    AppSection.tv,
    AppSection.radio,
    AppSection.film,
    AppSection.series,
    AppSection.favorites,
    AppSection.splitScreen,
    AppSection.sources,
  ];

  /// Çocuk profilinde tek bölüm Televizyon'dur (yalnız Çocuk kategorisi).
  static const kidsShortcutSections = [AppSection.tv];

  final String profileName;
  final String clock;

  /// Vitrin; kanal listesi boşsa null.
  final HomeHero? hero;
  final List<AppSection> shortcuts;

  /// Son izlenen kanallar (geçmiş boşsa ulusal kanallar).
  final List<LiveChannel> channels;

  /// Kanallar izleme geçmişinden mi (raf başlığı buna göre).
  final bool fromHistory;
}
