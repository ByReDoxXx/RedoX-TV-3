import '../../core/content/epg_program.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/m3u_parser.dart';
import '../../core/content/xmltv.dart';
import 'tv_preview_data.dart';

/// Televizyon sayfasının içeriği: kanallar, kategori sırası ve (varsa) yayın
/// akışı. Akış [withGuide] ile bağlanır; kanalların "şimdi" bilgisi o anki
/// saate göre dolar (TvGuideController her dakika yeniler).
class TvContent {
  const TvContent({required this.channels, this.guide, this.now});

  final List<LiveChannel> channels;

  /// Yayın akışı; null ise kanallardaki örnek program bilgisi kullanılır
  /// (tasarım önizlemesi).
  final EpgGuide? guide;

  /// "Şimdi": akış bu ana göre okunur; null ise önizlemenin sabit saati.
  final DateTime? now;

  /// [now] gün başından dakika olarak (EPG çizelgesindeki "şimdi" çizgisi).
  int? get nowMinute => switch (now) {
    final t? => t.hour * 60 + t.minute,
    null => null,
  };

  /// M3U metninden (kullanıcı kaynağı, testler). Uygulamanın kendi listesi
  /// şifreli paketten gelir (ChannelSource).
  factory TvContent.fromM3u(String text) => TvContent(channels: M3uParser.parse(text));

  /// Yalnız bu kategorinin kanalları (çocuk profili); akış ve saat korunur.
  TvContent only(String category) => TvContent(
    channels: [
      for (final c in channels)
        if (c.category == category) c,
    ],
    guide: guide,
    now: now,
  );

  /// Çip sırası (eski sürümdeki gibi sabit); listede olmayan kategoriler
  /// sonda, ilk görülme sırasıyla.
  static const categoryOrder = [
    'Ulusal',
    'Haber',
    'Spor',
    'Belgesel',
    'Sinema',
    'Müzik',
    'Çocuk',
    'Yaşam',
    'Dini',
    'Kıbrıs',
    'Dünya',
    'Genel',
    'Yerel',
    'Diğer',
  ];

  /// Kanallardaki kategoriler ("Tümü" arayüzdedir).
  List<String> get categories {
    // Küme sabiti ekleme sırasını korur.
    final seen = {for (final c in channels) c.category};
    return [
      for (final c in categoryOrder)
        if (seen.contains(c)) c,
      for (final c in seen)
        if (!categoryOrder.contains(c)) c,
    ];
  }

  /// Listede adı yayın akışındakinden farklı olan kanallar (M3U adı → akıştaki
  /// ad). Çoğu kanal adla eşleşir ([EpgGuide.key]).
  static const epgAliases = {'FB TV': 'FENERBAHÇE TV'};

  List<GuideEntry> _entries(EpgGuide g, LiveChannel c) => g.of(epgAliases[c.name] ?? c.name);

  /// Kanalları [now] anındaki programla doldurur: şimdiki program, saat
  /// aralığı, tür, ilerleme ve sonraki program. Akışta olmayan kanalın program
  /// bilgisi boşalır.
  TvContent withGuide(EpgGuide guide, DateTime now) =>
      TvContent(guide: guide, now: now, channels: [for (final c in channels) _onAir(c, _entries(guide, c), now)]);

  static LiveChannel _onAir(LiveChannel c, List<GuideEntry> e, DateTime now) {
    final i = e.indexWhere((p) => p.isLiveAt(now));
    if (i < 0) return c.withProgram();
    final p = e[i];
    return c.withProgram(
      programTitle: p.title,
      timeRange: '${_clock(p.start)} – ${_clock(p.stop)}',
      genre: p.category,
      progress: now.difference(p.start).inSeconds / p.stop.difference(p.start).inSeconds,
      next: i + 1 < e.length ? '${_clock(e[i + 1].start)} ${e[i + 1].title}' : null,
    );
  }

  static String _clock(DateTime t) => EpgProgram.formatClock(t.hour * 60 + t.minute);

  /// Kanalın EPG çizelgesi. Yayın akışı bağlıysa ondan: saatler [now]'ın
  /// günbaşından dakikadır (dün gece negatif, yarın 1440'tan büyük); akışta
  /// olmayan kanal "bilgi yok" bloğudur. Akış yoksa (önizleme) şimdiki ve
  /// sonraki programdan türetilir; öncesi ve sonrası kategoriye göre örnek
  /// kuşaklarla doldurulur (gerçek veri değildir).
  List<EpgProgram> scheduleOf(LiveChannel c) {
    final guide = this.guide;
    final now = this.now;
    if (guide != null && now != null) {
      final midnight = DateTime(now.year, now.month, now.day);
      final from = now.subtract(const Duration(hours: 6));
      final to = now.add(const Duration(hours: 24));
      final programs = [
        for (final e in _entries(guide, c))
          if (e.stop.isAfter(from) && e.start.isBefore(to))
            EpgProgram(
              title: e.title,
              start: e.start.difference(midnight).inMinutes,
              end: e.stop.difference(midnight).inMinutes,
            ),
      ];
      return programs.isEmpty ? const [EpgProgram.unknown()] : programs;
    }
    final timeRange = c.timeRange;
    final programTitle = c.programTitle;
    if (timeRange == null || programTitle == null) return const [EpgProgram.unknown()];
    final range = timeRange.split('–');
    final start = EpgProgram.parseClock(range.first);
    final end = range.length > 1 ? EpgProgram.parseClock(range.last) : null;
    if (start == null || end == null) return const [];
    final filler = _filler[c.category] ?? const ['Kuşak', 'Gece Kuşağı'];
    final nextTitle = c.next?.replaceFirst(RegExp(r'^\s*\d{1,2}:\d{2}\s*'), '');
    final nextEnd = end + 60;
    return [
      EpgProgram(title: filler.first, start: start - 120, end: start),
      EpgProgram(title: programTitle, start: start, end: end),
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
  /// uydurmadır, yayınlar herkese açık test yayınlarıdır).
  static const preview = TvContent(channels: tvPreviewChannels);
}
