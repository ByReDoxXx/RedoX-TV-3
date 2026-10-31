import '../../core/content/epg_program.dart';
import '../../core/content/live_channel.dart';
import '../../core/ui/channel_card.dart';

/// Televizyon sayfasının içeriği: kanallar ve kategori sırası. Veri katmanı
/// yazıldığında kaynaktan dolacak.
class TvContent {
  const TvContent({required this.channels});

  final List<LiveChannel> channels;

  /// Kanallardaki kategoriler, ilk görülme sırasıyla ("Tümü" arayüzdedir).
  /// (Küme sabiti ekleme sırasını korur.)
  List<String> get categories => {for (final c in channels) c.category}.toList();

  /// Kanalın EPG çizelgesi. Veri katmanı (XMLTV) yazılana kadar şimdiki ve
  /// sonraki programdan türetilir; öncesi ve sonrası kategoriye göre örnek
  /// kuşaklarla doldurulur (gerçek veri değildir).
  List<EpgProgram> scheduleOf(LiveChannel c) {
    final range = c.timeRange.split('–');
    final start = EpgProgram.parseClock(range.first);
    final end = range.length > 1 ? EpgProgram.parseClock(range.last) : null;
    if (start == null || end == null) return const [];
    final filler = _filler[c.category] ?? const ['Kuşak', 'Gece Kuşağı'];
    final nextTitle = c.next?.replaceFirst(RegExp(r'^\s*\d{1,2}:\d{2}\s*'), '');
    final nextEnd = end + 60;
    return [
      EpgProgram(title: filler.first, start: start - 120, end: start),
      EpgProgram(title: c.programTitle, start: start, end: end),
      if (nextTitle != null) EpgProgram(title: nextTitle, start: end, end: nextEnd),
      EpgProgram(title: filler.last, start: nextTitle == null ? end : nextEnd, end: 24 * 60 + 120),
    ];
  }

  static const _filler = {
    'Ulusal': ['Gündüz Kuşağı', 'Gece Kuşağı'],
    'Haber': ['Gün Ortası', 'Gece Bülteni'],
    'Spor': ['Spor Gündemi', 'Gece Özetleri'],
    'Belgesel': ['Doğa Kuşağı', 'Gece Belgeseli'],
    'Müzik': ['Klip Kuşağı', 'Gece Müzikleri'],
    'Çocuk': ['Çizgi Kuşak', 'Ninniler'],
  };

  /// Tasarım önizlemesi için örnek içerik (gerçek veri değildir; kanal adları
  /// uydurmadır).
  static const preview = TvContent(
    channels: [
      LiveChannel(
        name: 'ULUSAL 1 HD',
        number: 1,
        category: 'Ulusal',
        programTitle: 'Akşam Dizisi',
        timeRange: '20:00 – 22:30',
        genre: 'Dram',
        progress: 0.3,
        next: '22:30 Gece Haberleri',
        accent: CardAccent.gold,
      ),
      LiveChannel(
        name: 'ULUSAL 2',
        number: 2,
        category: 'Ulusal',
        programTitle: 'Yarışma Gecesi',
        timeRange: '20:15 – 22:00',
        genre: 'Eğlence',
        progress: 0.45,
        next: '22:00 Talk Show',
      ),
      LiveChannel(
        name: 'ULUSAL 3 HD',
        number: 3,
        category: 'Ulusal',
        programTitle: 'Kırık Kalpler',
        timeRange: '20:00 – 22:15',
        genre: 'Dram',
        progress: 0.35,
        next: '22:15 Belgesel Kuşağı',
        accent: CardAccent.amber,
      ),
      LiveChannel(
        name: 'ULUSAL 4',
        number: 4,
        category: 'Ulusal',
        programTitle: 'Akşam Haberleri',
        timeRange: '20:00 – 21:00',
        genre: 'Haber',
        progress: 0.75,
        next: '21:00 Spor Bülteni',
        live: true,
      ),
      LiveChannel(
        name: 'ULUSAL 5 HD',
        number: 5,
        category: 'Ulusal',
        programTitle: 'Gece Sineması',
        timeRange: '20:30 – 22:45',
        genre: 'Film',
        progress: 0.12,
        next: '22:45 Gece Kuşağı',
        accent: CardAccent.gold,
      ),
      LiveChannel(
        name: 'HABER 24',
        number: 24,
        category: 'Haber',
        programTitle: 'Ana Haber',
        timeRange: '20:00 – 21:00',
        genre: 'Haber',
        progress: 0.75,
        next: '21:00 Enine Boyuna',
        accent: CardAccent.amber,
        live: true,
      ),
      LiveChannel(
        name: 'GÜNDEM HABER',
        number: 25,
        category: 'Haber',
        programTitle: 'Gündem Özel',
        timeRange: '20:30 – 21:30',
        genre: 'Tartışma',
        progress: 0.25,
        next: '21:30 Dünya Gündemi',
      ),
      LiveChannel(
        name: 'EKONOMİ TV',
        number: 26,
        category: 'Haber',
        programTitle: 'Piyasa Kapanışı',
        timeRange: '20:00 – 20:45',
        genre: 'Ekonomi',
        progress: 0.9,
        next: '20:45 Borsa Özeti',
        accent: CardAccent.gold,
      ),
      LiveChannel(
        name: 'DÜNYA HABER',
        number: 27,
        category: 'Haber',
        programTitle: 'Dünya Bülteni',
        timeRange: '20:45 – 21:15',
        genre: 'Haber',
        progress: 0.05,
        next: '21:15 Bölge Raporu',
        accent: CardAccent.amber,
      ),
      LiveChannel(
        name: 'SPOR 1 4K',
        number: 104,
        category: 'Spor',
        programTitle: 'Çeyrek Final',
        timeRange: '19:45 – 22:00',
        genre: 'Futbol',
        progress: 0.74,
        next: '22:00 Maç Sonu',
        live: true,
      ),
      LiveChannel(
        name: 'SPOR 2 4K',
        number: 105,
        category: 'Spor',
        programTitle: 'Basketbol Ligi',
        timeRange: '20:30 – 22:30',
        genre: 'Basketbol',
        progress: 0.15,
        next: '22:30 Haftanın Özeti',
        live: true,
      ),
      LiveChannel(
        name: 'SPOR 3',
        number: 106,
        category: 'Spor',
        programTitle: 'Maç Önü',
        timeRange: '20:00 – 21:00',
        genre: 'Futbol',
        progress: 0.75,
        next: '21:00 Canlı Maç',
        accent: CardAccent.amber,
      ),
      LiveChannel(
        name: 'ARENA SPOR',
        number: 107,
        category: 'Spor',
        programTitle: 'Tenis: Yarı Final',
        timeRange: '19:00 – 21:30',
        genre: 'Tenis',
        progress: 0.7,
        next: '21:30 Tenis Analiz',
        accent: CardAccent.gold,
        live: true,
      ),
      LiveChannel(
        name: 'BELGESEL HD',
        number: 42,
        category: 'Belgesel',
        programTitle: 'Derin Uzay',
        timeRange: '20:30 – 21:45',
        genre: 'Bilim',
        progress: 0.2,
        next: '21:45 Gezegenimiz',
        accent: CardAccent.gold,
      ),
      LiveChannel(
        name: 'DOĞA TV',
        number: 43,
        category: 'Belgesel',
        programTitle: 'Okyanusun Sırları',
        timeRange: '20:00 – 21:00',
        genre: 'Doğa',
        progress: 0.75,
        next: '21:00 Vahşi Afrika',
        accent: CardAccent.amber,
      ),
      LiveChannel(
        name: 'TARİH KANALI',
        number: 44,
        category: 'Belgesel',
        programTitle: 'Antik Kentler',
        timeRange: '20:15 – 21:15',
        genre: 'Tarih',
        progress: 0.5,
        next: '21:15 Kayıp Uygarlıklar',
      ),
      LiveChannel(
        name: 'MÜZİK HİT',
        number: 60,
        category: 'Müzik',
        programTitle: 'Haftanın Listesi',
        timeRange: '20:00 – 22:00',
        genre: 'Pop',
        progress: 0.38,
        next: '22:00 Gece Listesi',
        accent: CardAccent.amber,
      ),
      LiveChannel(
        name: 'TÜRKÜ TV',
        number: 61,
        category: 'Müzik',
        programTitle: 'Bozlak Gecesi',
        timeRange: '20:30 – 22:00',
        genre: 'Halk müziği',
        progress: 0.17,
        next: '22:00 Ezgiler',
        accent: CardAccent.gold,
      ),
      LiveChannel(
        name: 'ÇOCUK TV',
        number: 70,
        category: 'Çocuk',
        programTitle: 'Uzay Kedileri',
        timeRange: '20:00 – 20:30',
        genre: 'Çizgi film',
        progress: 0.9,
        next: '20:30 Robot Dostlar',
      ),
      LiveChannel(
        name: 'MİNİK KANAL',
        number: 71,
        category: 'Çocuk',
        programTitle: 'Masal Saati',
        timeRange: '20:15 – 20:45',
        genre: 'Çocuk',
        progress: 0.5,
        next: '20:45 Uyku Masalı',
        accent: CardAccent.amber,
      ),
    ],
  );
}
