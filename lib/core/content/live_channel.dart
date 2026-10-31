import '../ui/channel_card.dart';

/// Canlı kanal (Anasayfa "Son izlenen kanallar" ve Televizyon sayfası).
/// Veri katmanı (GitHub'daki şifreli JSON) yazıldığında bu modele eşlenecek;
/// burada ağ veya depolama API'si yoktur.
class LiveChannel {
  const LiveChannel({
    required this.name,
    required this.number,
    required this.category,
    required this.programTitle,
    required this.timeRange,
    required this.genre,
    required this.progress,
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

  /// Şu an yayındaki program.
  final String programTitle;

  /// Örn. "20:00 – 22:30".
  final String timeRange;

  /// Programın türü, örn. "Dram".
  final String genre;
  final double progress;
  final CardAccent accent;

  /// Canlı yayın rozeti (maç, haber bülteni gibi).
  final bool live;
}
