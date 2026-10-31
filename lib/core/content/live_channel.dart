import '../ui/channel_card.dart';

/// Canlı kanal (Anasayfa "Son izlenen kanallar" ve Televizyon sayfası).
/// Program bilgileri (yayın akışı, EPG) isteğe bağlıdır: M3U listelerinde
/// yoktur; yayın akışı (XMLTV) gelince [withProgram] ile dolar. Burada ağ veya
/// depolama API'si yoktur.
///
/// Eşitlik numara ve addır: program bilgisi her dakika yenilenince kanal yeni
/// nesne olur, ama aynı kanal sayılır (önizleme seçimi, dizideki yeri).
class LiveChannel {
  const LiveChannel({
    required this.name,
    required this.number,
    required this.category,
    this.programTitle,
    this.timeRange,
    this.genre,
    this.progress,
    this.accent = CardAccent.crimson,
    this.live = false,
    this.next,
    this.logoUrl,
    this.streams = const [],
  });

  /// Yayın adresleri (HLS/MPEG-TS), öncelik sırasıyla: "Akış 1/2". İlki
  /// açılmazsa oynatıcı sıradakine geçer.
  final List<String> streams;

  /// Sonraki program, örn. "22:30 Maç Özetleri".
  final String? next;

  /// Kanal logosu (M3U tvg-logo); null ise baş harfli yer tutucu çizilir.
  final String? logoUrl;

  final String name;

  /// TKGS kanal numarası.
  final int number;

  /// Televizyon sayfasındaki kategori çipi, örn. "Ulusal", "Spor".
  final String category;

  /// Şu an yayındaki program; yayın akışı yoksa null.
  final String? programTitle;

  /// Örn. "20:00 – 22:30".
  final String? timeRange;

  /// Programın türü, örn. "Dram".
  final String? genre;

  /// Şimdiki programın ilerlemesi (0–1).
  final double? progress;
  final CardAccent accent;

  /// Canlı yayın rozeti (maç, haber bülteni gibi).
  final bool live;

  /// Aynı kanal, yayın akışından gelen program bilgisiyle (null: bilgi yok).
  LiveChannel withProgram({String? programTitle, String? timeRange, String? genre, double? progress, String? next}) =>
      LiveChannel(
        name: name,
        number: number,
        category: category,
        programTitle: programTitle,
        timeRange: timeRange,
        genre: genre,
        progress: progress,
        accent: accent,
        live: live,
        next: next,
        logoUrl: logoUrl,
        streams: streams,
      );

  @override
  bool operator ==(Object other) => other is LiveChannel && other.number == number && other.name == name;

  @override
  int get hashCode => Object.hash(number, name);
}
