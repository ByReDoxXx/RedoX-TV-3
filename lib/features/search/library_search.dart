import 'dart:isolate';

import '../../core/content/live_channel.dart';
import '../../core/content/series_catalog.dart';
import '../../core/content/user_sources.dart';
import 'search_page.dart';

/// Aramanın Film ve Dizi tarafı (kullanıcı isteği: "filmler ve diziler
/// yüklenmesine rağmen arama bulamıyor"): bütün Film kaynaklarının kayıtları
/// ve Dizi kaynaklarının dizileri, adları sadeleştirilmiş ([SearchPage.fold])
/// olarak. Sadeleştirme ayrı iş parçacığında: 145 bin filmlik listede ana iş
/// parçacığında Chromecast'i donduruyordu (Film sayfasındaki ANR'ye benzer).
class LibrarySearch {
  LibrarySearch._(this.films, this.series, this._filmKeys, this._seriesKeys);

  static const empty = LibrarySearch._fixed();

  const LibrarySearch._fixed() : films = const [], series = const [], _filmKeys = const [], _seriesKeys = const [];

  final List<LiveChannel> films;
  final List<Series> series;
  final List<String> _filmKeys;
  final List<String> _seriesKeys;

  /// Bu sayıdan az adda sadeleştirme ana iş parçacığında.
  static const isolateThreshold = 2000;

  static Future<LibrarySearch> load(UserSources sources) async {
    final films = [for (final s in sources.of(SourceKind.film)) ...await sources.channels(s)];
    final series = SeriesCatalog.build([
      for (final s in sources.of(SourceKind.series)) (s.id, await sources.channels(s)),
    ]);
    final names = [for (final f in films) f.name, for (final s in series) s.name];
    final keys = names.length < isolateThreshold ? _fold(names) : await _foldInIsolate(names);
    return LibrarySearch._(films, series, keys.sublist(0, films.length), keys.sublist(films.length));
  }

  static List<String> _fold(List<String> names) => [for (final n in names) SearchPage.fold(n)];

  /// Ayrı işlev: isolate'a yalnız adlar gider.
  static Future<List<String>> _foldInIsolate(List<String> names) => Isolate.run(() => _fold(names));

  /// Adında [query] geçen filmler (en çok [SearchPage.limit]).
  List<LiveChannel> matchFilms(String query) => _match(films, _filmKeys, query);

  /// Adında [query] geçen diziler (en çok [SearchPage.limit]).
  List<Series> matchSeries(String query) => _match(series, _seriesKeys, query);

  static List<T> _match<T>(List<T> items, List<String> keys, String query) {
    final q = SearchPage.fold(query.trim());
    if (q.isEmpty) return const [];
    final out = <T>[];
    for (var i = 0; i < items.length && out.length < SearchPage.limit; i++) {
      if (keys[i].contains(q)) out.add(items[i]);
    }
    return out;
  }
}
