import 'dart:isolate';
import 'dart:typed_data';

/// Film/Dizi süzgeci (kullanıcı isteği: "Kategori, Tür, yıl gibi
/// filtreleme"): listenin kategorisi, tür ve yıl aralığı; null olan süzülmez.
class LibraryFilter {
  const LibraryFilter({this.category, this.genre, this.years});

  final String? category;
  final String? genre;

  /// Tek yıl (2023–2023) ya da onyıl (2020–2029).
  final YearRange? years;

  bool get isEmpty => category == null && genre == null && years == null;

  LibraryFilter withCategory(String? value) => LibraryFilter(category: value, genre: genre, years: years);
  LibraryFilter withGenre(String? value) => LibraryFilter(category: category, genre: value, years: years);
  LibraryFilter withYears(YearRange? value) => LibraryFilter(category: category, genre: genre, years: value);

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter && other.category == category && other.genre == genre && other.years == years;

  @override
  int get hashCode => Object.hash(category, genre, years);
}

/// Yıl aralığı (iki uç dahil).
class YearRange {
  const YearRange(this.from, this.to);

  const YearRange.year(int year) : from = year, to = year;

  /// Yılın onyılı: 2023 → 2020–2029.
  YearRange.decadeOf(int year) : from = year - year % 10, to = year - year % 10 + 9;

  final int from;
  final int to;

  bool get isDecade => to - from == 9 && from % 10 == 0;

  bool contains(int year) => year >= from && year <= to;

  /// "2023" ya da "2020'ler" (Türkçe ek onyılın okunuşuna göre).
  String get label => isDecade ? decadeLabel(from) : '$from';

  static String decadeLabel(int decade) {
    final soft = switch (decade % 100) {
      0 || 20 || 50 || 70 || 80 => true,
      _ => false,
    };
    return "$decade'${soft ? 'ler' : 'lar'}";
  }

  @override
  bool operator ==(Object other) => other is YearRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Süzgeç seçeneği: değeri (null: Tümü), etiketi ve eşleşen kayıt sayısı.
typedef FilterOption<V> = ({V? value, String label, int count});

/// Bir listenin süzgeç dizini: her kaydın kategorisi, türleri (kategori
/// adındaki tür sözcüklerinden: "TR | Aksiyon - Macera" → Aksiyon, Macera;
/// listelerde ayrı tür alanı yok) ve yılı (addan: "Ad (2023)", "Ad 2023").
/// Seçenek sayıları öteki süzgeçler uygulanmış olarak sayılır.
class FilterIndex<T> {
  FilterIndex._(this.items, this._categories, this._genres, this._years);

  /// [items] için dizin. Büyük listede yıllar ayrı isolate'ta çıkarılır (145 bin
  /// adı ana iş parçacığında taramak Chromecast'i donduruyordu, ANR).
  static Future<FilterIndex<T>> build<T>(
    List<T> items, {
    required String Function(T) categoryOf,
    required String Function(T) nameOf,
    int? maxYear,
  }) async {
    final categories = [for (final x in items) categoryOf(x)];
    final genres = {for (final c in categories.toSet()) c: genresOf(c)};
    final names = [for (final x in items) nameOf(x)];
    final max = maxYear ?? DateTime.now().year + 1;
    final years = names.length < isolateThreshold ? _yearsOf(names, max) : await _yearsInIsolate(names, max);
    return FilterIndex._(items, categories, genres, years);
  }

  /// Bu sayıdan kısa listenin yılları ana iş parçacığında çıkarılır.
  static const isolateThreshold = 2000;

  final List<T> items;
  final List<String> _categories;
  final Map<String, List<String>> _genres;

  /// Kaydın yılı; 0: addan çıkmadı.
  final Uint16List _years;

  static Uint16List _yearsOf(List<String> names, int maxYear) =>
      Uint16List.fromList([for (final n in names) yearOf(n, maxYear: maxYear) ?? 0]);

  /// Ayrı işlev: isolate'a yalnız adlar gider (kayıtlar kopyalanmaz).
  static Future<Uint16List> _yearsInIsolate(List<String> names, int maxYear) =>
      Isolate.run(() => _yearsOf(names, maxYear));

  bool _matches(int i, LibraryFilter f, {bool category = true, bool genre = true, bool years = true}) {
    if (category && f.category != null && _categories[i] != f.category) return false;
    if (genre && f.genre != null && !_genres[_categories[i]]!.contains(f.genre)) return false;
    if (years && f.years != null && !f.years!.contains(_years[i])) return false;
    return true;
  }

  /// Süzgeçle eşleşen kayıtlar (sıra korunur).
  List<T> apply(LibraryFilter f) => f.isEmpty
      ? items
      : [
          for (var i = 0; i < items.length; i++)
            if (_matches(i, f)) items[i],
        ];

  /// Kategoriler (listedeki sırayla), Tümü başta.
  List<FilterOption<String>> categories(LibraryFilter f) {
    final counts = <String, int>{for (final c in _categories) c: 0};
    var all = 0;
    for (var i = 0; i < items.length; i++) {
      if (!_matches(i, f, category: false)) continue;
      counts[_categories[i]] = counts[_categories[i]]! + 1;
      all++;
    }
    return [
      (value: null, label: 'Tümü', count: all),
      for (final MapEntry(:key, :value) in counts.entries)
        if (value > 0 || key == f.category) (value: key, label: key, count: value),
    ];
  }

  /// Listede geçen türler (tür tablosu sırasıyla), Tümü başta.
  List<FilterOption<String>> genres(LibraryFilter f) {
    final counts = <String, int>{};
    var all = 0;
    for (var i = 0; i < items.length; i++) {
      if (!_matches(i, f, genre: false)) continue;
      for (final g in _genres[_categories[i]]!) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
      all++;
    }
    return [
      (value: null, label: 'Tümü', count: all),
      for (final (g, _) in _table)
        if (counts[g] != null || g == f.genre) (value: g, label: g, count: counts[g] ?? 0),
    ];
  }

  /// Yıllar onyıllara bölünmüş, yeniden eskiye: her bölümün başında onyıl
  /// ("2020'ler"), ardından yılları. İlk bölüm yalnız Tümü.
  List<List<FilterOption<YearRange>>> years(LibraryFilter f) {
    final counts = <int, int>{};
    var all = 0;
    for (var i = 0; i < items.length; i++) {
      if (!_matches(i, f, years: false)) continue;
      all++;
      if (_years[i] != 0) counts[_years[i]] = (counts[_years[i]] ?? 0) + 1;
    }
    if (f.years case final r?) {
      for (var y = r.from; y <= r.to && !r.isDecade; y++) {
        counts[y] ??= 0;
      }
    }
    final byDecade = <int, List<int>>{};
    for (final y in counts.keys.toList()..sort((a, b) => b.compareTo(a))) {
      byDecade.putIfAbsent(y - y % 10, () => []).add(y);
    }
    return [
      [(value: null, label: 'Tümü', count: all)],
      for (final MapEntry(key: decade, value: list) in byDecade.entries)
        [
          (
            value: YearRange(decade, decade + 9),
            label: YearRange.decadeLabel(decade),
            count: list.fold(0, (n, y) => n + counts[y]!),
          ),
          for (final y in list) (value: YearRange.year(y), label: '$y', count: counts[y]!),
        ],
    ];
  }

  /// Listede tür var mı (Tür süzgeci gösterilir).
  bool get hasGenres => _genres.values.any((g) => g.isNotEmpty);

  /// Listede yıl var mı (Yıl süzgeci gösterilir).
  bool get hasYears => _years.any((y) => y != 0);

  /// Listede birden çok kategori var mı (Kategori süzgeci gösterilir).
  bool get hasCategories => _genres.length > 1;

  static final _paren = RegExp(r'[(\[]((?:19|20)\d{2})[)\]]');
  static final _bare = RegExp(r'(?:^|[\s._\-|:])((?:19|20)\d{2})(?=$|[\s._\-|:])');

  /// Kayıt adındaki yapım yılı: "Başlangıç (2010) [4K]" → 2010, "Dune 2021"
  /// → 2021; ad yalnız yıldan oluşuyorsa ("1917") ya da yıl [maxYear]'dan
  /// büyükse ("Blade Runner 2049") null.
  static int? yearOf(String name, {required int maxYear}) {
    int? valid(Match? m) => switch (int.tryParse(m?[1] ?? '')) {
      final y? when y <= maxYear => y,
      _ => null,
    };
    if (valid(_paren.allMatches(name).lastOrNull) case final y?) return y;
    final bare = _bare.allMatches(name).lastOrNull;
    if (bare == null || name.replaceRange(bare.start, bare.end, '').trim().isEmpty) return null;
    return valid(bare);
  }

  /// Tür adı ve kategori adında aranan sözcük başları (Türkçe harfler
  /// sadeleştirilmiş: ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u).
  static final List<(String, RegExp)> _table = [
    for (final (genre, words) in const [
      ('Aksiyon', r'aksiyon|action'),
      ('Macera', r'macera|adventure'),
      ('Komedi', r'komedi|comed'),
      ('Dram', r'dram|drama'),
      ('Gerilim', r'gerilim|thriller'),
      ('Korku', r'korku|horror'),
      ('Bilim Kurgu', r'bilim\s*-?\s*kurgu|sci\s*-?\s*fi\b|science\s*fiction'),
      ('Fantastik', r'fantasti|fantasy'),
      ('Animasyon', r'animasyon|animation|anime\b|cizgi|cartoon'),
      ('Aile', r'aile\b|family'),
      ('Çocuk', r'cocuk|kids?\b|children'),
      ('Romantik', r'romanti|romance'),
      ('Suç', r'suc\b|polisiye|crime'),
      ('Gizem', r'gizem|mystery'),
      ('Savaş', r'savas|war\b'),
      ('Tarih', r'tarih|histor'),
      ('Biyografi', r'biyografi|biograph'),
      ('Belgesel', r'belgesel|documentar'),
      ('Müzik', r'muzik|music'),
      ('Western', r'western|kovboy'),
      ('Spor', r'spor\b|sports?\b'),
    ])
      (genre, RegExp('(?:^|[^a-z])(?:$words)')),
  ];

  /// Kategori adındaki türler (tablo sırasıyla): "TR | AKSİYON - MACERA" →
  /// [Aksiyon, Macera]; "Netflix" → [].
  static List<String> genresOf(String category) {
    final s = _fold(category);
    return [
      for (final (genre, pattern) in _table)
        if (pattern.hasMatch(s)) genre,
    ];
  }

  static const _plain = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', '̇': ''};

  /// Küçük harf, Türkçe harfler ASCII ("BİLİM KURGU" → "bilim kurgu").
  static String _fold(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAllMapped(RegExp('[çğıöşü̇]'), (m) => _plain[m[0]]!);
}
