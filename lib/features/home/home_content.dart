import '../../core/ui/channel_card.dart';
import '../../core/ui/redox_icon.dart';

// Anasayfa'nın gösterim modelleri. Veri katmanı (GitHub'daki şifreli JSON)
// yazıldığında bu modellere eşlenecek; burada ağ veya depolama API'si yoktur.

class HomeHero {
  const HomeHero({
    required this.channelName,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.phase,
    required this.clock,
    required this.progress,
    required this.tech,
  });

  final String channelName;
  final int number;
  final String title;
  final String subtitle;

  /// Örn. "2. yarı · 68. dakika".
  final String phase;

  /// Örn. "45:12 / 90:00".
  final String clock;
  final double progress;

  /// Teknik bilgi rozeti, örn. "4K · HDR10".
  final String tech;
}

class HomeStory {
  const HomeStory(this.label, this.icon, {this.seen = false});

  final String label;
  final RedoxIcons icon;
  final bool seen;
}

class HomeChannel {
  const HomeChannel({
    required this.name,
    required this.number,
    required this.programTitle,
    required this.timeRange,
    required this.genre,
    required this.progress,
    this.accent = CardAccent.crimson,
    this.live = false,
  });

  final String name;
  final int number;
  final String programTitle;
  final String timeRange;
  final String genre;
  final double progress;
  final CardAccent accent;
  final bool live;
}

class HomeContinueItem {
  const HomeContinueItem({
    required this.title,
    required this.detail,
    required this.remaining,
    required this.progress,
    required this.icon,
  });

  final String title;

  /// Örn. "2. sezon · 5. bölüm" veya "Film · 2024".
  final String detail;

  /// Örn. "18 dk kaldı".
  final String remaining;
  final double progress;
  final RedoxIcons icon;
}

class HomeRadio {
  const HomeRadio(this.name, this.genre);

  final String name;
  final String genre;
}

class HomeFilm {
  const HomeFilm(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class HomeContent {
  const HomeContent({
    required this.profileName,
    required this.clock,
    required this.hero,
    required this.stories,
    required this.channels,
    required this.continueItems,
    required this.radios,
    required this.films,
  });

  final String profileName;
  final String clock;
  final HomeHero hero;

  /// En yeni kanallar ve özellikler.
  final List<HomeStory> stories;

  /// Son izlenen kanallar.
  final List<HomeChannel> channels;

  /// Yarım kalan dizi ve filmler.
  final List<HomeContinueItem> continueItems;

  /// Son dinlenen radyolar.
  final List<HomeRadio> radios;

  /// Son izlenen filmler.
  final List<HomeFilm> films;

  /// Tasarım önizlemesi için örnek içerik (gerçek veri değildir).
  static const preview = HomeContent(
    profileName: 'Profil 1',
    clock: '20:45',
    hero: HomeHero(
      channelName: 'Spor 1 4K',
      number: 104,
      title: 'Şampiyonlar Ligi — Çeyrek Final',
      subtitle: 'Ev sahibi – Deplasman · Canlı · Türkçe anlatım',
      phase: '2. yarı · 68. dakika',
      clock: '68:12 / 90:00',
      progress: 0.74,
      tech: '4K · HDR10',
    ),
    stories: [
      HomeStory('Spor 2 4K', RedoxIcons.television),
      HomeStory('Belgesel+', RedoxIcons.television),
      HomeStory('Caz Radyo', RedoxIcons.radio),
      HomeStory('Çoklu ekran', RedoxIcons.splitScreen),
      HomeStory('QR kaynak', RedoxIcons.qrCode),
      HomeStory('Kumanda', RedoxIcons.remote, seen: true),
    ],
    channels: [
      HomeChannel(
        name: 'ULUSAL 1 HD',
        number: 1,
        programTitle: 'Akşam Dizisi',
        timeRange: '20:00 – 22:30',
        genre: 'Dram',
        progress: 0.3,
        accent: CardAccent.gold,
      ),
      HomeChannel(
        name: 'SPOR 1 4K',
        number: 104,
        programTitle: 'Çeyrek Final',
        timeRange: '19:45 – 22:00',
        genre: 'Futbol',
        progress: 0.74,
        live: true,
      ),
      HomeChannel(
        name: 'HABER 24',
        number: 24,
        programTitle: 'Ana Haber',
        timeRange: '20:00 – 21:00',
        genre: 'Haber',
        progress: 0.75,
        accent: CardAccent.amber,
      ),
      HomeChannel(
        name: 'BELGESEL HD',
        number: 42,
        programTitle: 'Derin Uzay',
        timeRange: '20:30 – 21:45',
        genre: 'Bilim',
        progress: 0.2,
        accent: CardAccent.gold,
      ),
    ],
    continueItems: [
      HomeContinueItem(
        title: 'Örnek Dizi',
        detail: '2. sezon · 5. bölüm',
        remaining: '18 dk kaldı',
        progress: 0.6,
        icon: RedoxIcons.series,
      ),
      HomeContinueItem(
        title: 'Örnek Film',
        detail: 'Film · 2024',
        remaining: '42 dk kaldı',
        progress: 0.65,
        icon: RedoxIcons.film,
      ),
    ],
    radios: [
      HomeRadio('Caz Radyo', 'Caz'),
      HomeRadio('Pop FM', 'Pop'),
      HomeRadio('Haber Radyo', 'Haber'),
      HomeRadio('Türkü FM', 'Halk müziği'),
    ],
    films: [
      HomeFilm('Çöl Gezegeni', '2024 · 2 sa 46 dk'),
      HomeFilm('Gece Treni', '2023 · 1 sa 58 dk'),
      HomeFilm('Mavi Derinlik', '2022 · 1 sa 40 dk'),
      HomeFilm('Son Vardiya', '2024 · 2 sa 5 dk'),
      HomeFilm('Kuzey Işığı', '2021 · 1 sa 52 dk'),
    ],
  );
}
