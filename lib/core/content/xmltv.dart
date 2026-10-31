import 'package:xml/xml.dart';

/// XMLTV yayın akışındaki tek program (gerçek tarih/saatle).
class GuideEntry {
  const GuideEntry({required this.title, required this.start, required this.stop, this.category});

  final String title;
  final DateTime start;
  final DateTime stop;

  /// Program türü (XMLTV `category`), örn. "Dizi".
  final String? category;

  bool isLiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(stop);
}

/// XMLTV yayın akışı: kanal adına göre programlar. Kanallar M3U listesindeki
/// adlarıyla eşlenir ([key]): kaynakların kimlikleri (örn. "TRT.1.HD.tr")
/// listedeki kimliklerle ortak değildir. Burada ağ API'si yoktur.
class EpgGuide {
  const EpgGuide(this._byKey);

  static const empty = EpgGuide({});

  final Map<String, List<GuideEntry>> _byKey;

  /// Akışı olan kanal sayısı (aynı kanalın "HD" adı ayrı sayılmaz).
  int get channelCount => _byKey.length;

  /// Kanalın programları, başlangıca göre sıralı; akışı yoksa boş.
  List<GuideEntry> of(String channelName) => _byKey[key(channelName)] ?? const [];

  /// Ad eşleme anahtarı: küçük harf, aksansız (ı → i), "HD/FHD/UHD/4K/SD/TV/TR"
  /// gibi ekler ve boşluk/noktalama atılır. "TRT 1 HD", "TRT.1" ve "TRT 1"
  /// aynı anahtarı verir; "Bengütürk TV" ile "BENGÜ TÜRK" de.
  static String key(String name) {
    // "İ".toLowerCase() "i" + U+0307 (birleşen nokta) verir.
    var s = name.toLowerCase().replaceAll('̇', '');
    const fold = {'ı': 'i', 'ğ': 'g', 'ü': 'u', 'ş': 's', 'ö': 'o', 'ç': 'c', 'â': 'a', 'î': 'i', 'û': 'u'};
    s = s.split('').map((ch) => fold[ch] ?? ch).join();
    s = s.replaceAll(RegExp(r'\b(hd|fhd|uhd|4k|sd|tv|tr)\b'), ' ');
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  /// XMLTV metnini çözer. Başlığı ya da saati okunamayan program atlanır.
  /// Aynı kanalın birden çok kimliği (örn. "TRT 1" ve "TRT 1 HD") tek
  /// anahtarda birleşir; aynı başlangıçlı program bir kez tutulur.
  static EpgGuide parse(String xml) {
    final doc = XmlDocument.parse(xml);
    final tv = doc.rootElement;
    final names = <String, String>{};
    for (final ch in tv.findElements('channel')) {
      final id = ch.getAttribute('id');
      if (id != null) names[id] = ch.getElement('display-name')?.innerText ?? id;
    }
    final byKey = <String, Map<DateTime, GuideEntry>>{};
    for (final p in tv.findElements('programme')) {
      final id = p.getAttribute('channel');
      final start = parseTime(p.getAttribute('start') ?? '');
      final stop = parseTime(p.getAttribute('stop') ?? '');
      final title = p.getElement('title')?.innerText.trim() ?? '';
      if (id == null || start == null || stop == null || title.isEmpty || !stop.isAfter(start)) continue;
      final category = p.getElement('category')?.innerText.trim();
      (byKey[key(names[id] ?? id)] ??= {})[start] = GuideEntry(
        title: title,
        start: start,
        stop: stop,
        category: category == null || category.isEmpty ? null : category,
      );
    }
    return EpgGuide({
      for (final e in byKey.entries) e.key: e.value.values.toList()..sort((a, b) => a.start.compareTo(b.start)),
    });
  }

  /// XMLTV saati: "20261031201500 +0300" → yerel saat. Dilim yoksa UTC sayılır
  /// (XMLTV belgesi böyle der).
  static DateTime? parseTime(String text) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-])?(\d{2})?(\d{2})?').firstMatch(text.trim());
    if (m == null) return null;
    int g(int i) => int.parse(m[i] ?? '0');
    final utc = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
    final offset = m[7] == null ? Duration.zero : Duration(hours: g(8), minutes: g(9)) * (m[7] == '-' ? -1 : 1);
    return utc.subtract(offset).toLocal();
  }
}
