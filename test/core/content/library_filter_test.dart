import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/library_filter.dart';

typedef _Film = ({String name, String category});

Future<FilterIndex<_Film>> _index(List<_Film> films) =>
    FilterIndex.build(films, categoryOf: (f) => f.category, nameOf: (f) => f.name, maxYear: 2026);

void main() {
  test('genresOf: kategori adındaki türler (büyük harf, ASCII ve İngilizce)', () {
    expect(FilterIndex.genresOf('TR | AKSİYON - MACERA'), ['Aksiyon', 'Macera']);
    expect(FilterIndex.genresOf('AKSIYON'), ['Aksiyon']);
    expect(FilterIndex.genresOf('Bilim Kurgu & Fantastik'), ['Bilim Kurgu', 'Fantastik']);
    expect(FilterIndex.genresOf('EN: Sci-Fi / Horror'), ['Korku', 'Bilim Kurgu']);
    expect(FilterIndex.genresOf('Yerli Dram'), ['Dram']);
    expect(FilterIndex.genresOf('Netflix'), isEmpty);
    expect(FilterIndex.genresOf('Warner Bros'), isEmpty);
  });

  test('yearOf: ayraçlı ya da çıplak yıl; yalnız yıl olan ad ve gelecek yıl sayılmaz', () {
    int? y(String n) => FilterIndex.yearOf(n, maxYear: 2026);
    expect(y('TR: Başlangıç (2010) [4K]'), 2010);
    expect(y('Dune 2021 1080p'), 2021);
    expect(y('Film [1999]'), 1999);
    expect(y('1917'), isNull);
    expect(y('Blade Runner 2049'), isNull);
    expect(y('Yıldızlararası'), isNull);
  });

  test('YearRange: onyıl etiketi Türkçe ekle', () {
    expect(YearRange.decadeOf(2023), const YearRange(2020, 2029));
    expect(YearRange.decadeOf(2023).label, "2020'ler");
    expect(YearRange.decadeLabel(2010), "2010'lar");
    expect(YearRange.decadeLabel(2000), "2000'ler");
    expect(YearRange.decadeLabel(1990), "1990'lar");
    expect(YearRange.decadeLabel(1980), "1980'ler");
    expect(const YearRange.year(2023).label, '2023');
  });

  test('apply: kategori, tür ve yıl birlikte süzer; sayılar öteki süzgeçlerle', () async {
    final index = await _index(const [
      (name: 'A (2023)', category: 'Aksiyon'),
      (name: 'B (2015)', category: 'Aksiyon - Komedi'),
      (name: 'C (2023)', category: 'Komedi'),
      (name: 'D', category: 'Netflix'),
    ]);
    expect(index.hasCategories && index.hasGenres && index.hasYears, isTrue);
    expect(index.apply(const LibraryFilter()).length, 4);
    expect(index.apply(const LibraryFilter(genre: 'Komedi')).map((f) => f.name), ['B (2015)', 'C (2023)']);
    expect(index.apply(const LibraryFilter(genre: 'Komedi', years: YearRange(2020, 2029))).map((f) => f.name), [
      'C (2023)',
    ]);
    expect(index.apply(const LibraryFilter(category: 'Netflix', years: YearRange.year(2023))), isEmpty);

    const komedi = LibraryFilter(genre: 'Komedi');
    expect(index.genres(const LibraryFilter()).map((o) => (o.label, o.count)), [
      ('Tümü', 4),
      ('Aksiyon', 2),
      ('Komedi', 2),
    ]);
    expect(index.categories(komedi).map((o) => (o.label, o.count)), [
      ('Tümü', 2),
      ('Aksiyon - Komedi', 1),
      ('Komedi', 1),
    ]);
    final years = index.years(komedi);
    expect(years.first.single.count, 2);
    expect(years.skip(1).map((s) => [for (final o in s) (o.label, o.count)]), [
      [("2020'ler", 1), ('2023', 1)],
      [("2010'lar", 1), ('2015', 1)],
    ]);
  });

  test('büyük listede yıllar ayrı isolate’ta çıkarılır', () async {
    final index = await _index([
      for (var i = 0; i < FilterIndex.isolateThreshold + 10; i++)
        (name: 'Film $i (${1990 + i % 30})', category: 'Dram'),
    ]);
    expect(index.apply(const LibraryFilter(years: YearRange.year(2000))).length, 67);
  });
}
