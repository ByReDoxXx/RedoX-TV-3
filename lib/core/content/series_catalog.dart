import 'channel_folder.dart';
import 'live_channel.dart';
import 'm3u_parser.dart';

/// Dizinin bir bölümü.
class Episode {
  const Episode({required this.channel, required this.season, required this.number, required this.title});

  final LiveChannel channel;
  final int season;

  /// Bölüm numarası; adda yoksa listedeki sırası.
  final int number;

  /// Bölümün adı ("S01E02" sonrası); yoksa boş.
  final String title;

  /// Listede görünen ad: "Bölüm 2 · Başlık".
  String get label => title.isEmpty ? 'Bölüm $number' : 'Bölüm $number · $title';
}

/// Bir dizi: adı, kategorisi (grup), kaynağı ve sezonları.
class Series {
  Series({required this.name, required this.category, required this.sourceId});

  final String name;
  final String category;

  /// Dizinin geldiği ilk liste (kilit anahtarı için).
  final String sourceId;
  final _seasons = <int, List<Episode>>{};

  /// Sezon numaraları, küçükten büyüğe.
  List<int> get seasons => _seasons.keys.toList()..sort();

  /// Sezonun bölümleri, numara sırasıyla.
  List<Episode> episodes(int season) => _seasons[season] ?? const [];

  int get episodeCount => _seasons.values.fold(0, (n, l) => n + l.length);

  /// Listedeki ilk görsel (bölümlerin logosu/afişi); yoksa null.
  String? get poster => _seasons.values.expand((l) => l).map((e) => e.channel.logoUrl).nonNulls.firstOrNull;

  /// İlk sezonun ilk bölümü ("İzle").
  Episode get first => episodes(seasons.first).first;

  /// Afiş köşesinde kısa bilgi: "3 sezon" ya da (tek sezonda) "42 bölüm".
  String get shortSummary => seasons.length > 1 ? '${seasons.length} sezon' : '$episodeCount bölüm';

  /// "3 sezon · 42 bölüm" (tek sezonda yalnız bölüm sayısı).
  String get summary => seasons.length > 1 ? '${seasons.length} sezon · $episodeCount bölüm' : '$episodeCount bölüm';
}

/// Dizi listelerindeki kayıtlardan diziler (Dizi bölümü). Bölüm adları
/// "Dizi S01E02" ya da "Dizi 1. Sezon 2. Bölüm" ise dizi, sezon ve bölüm
/// addan çıkar; değilse grup adı dizi, kayıtlar tek sezonun bölümleri olur
/// (sıralarıyla). Aynı adlı diziler (farklı listelerden) birleşir.
abstract final class SeriesCatalog {
  static List<Series> build(List<(String sourceId, List<LiveChannel> channels)> sources) {
    final byName = <String, Series>{};
    for (final (sourceId, channels) in sources) {
      final loose = <String, int>{};
      for (final c in channels) {
        final parsed = ChannelFolder.parseEpisode(c.name);
        final group = c.category == M3uParser.noGroup || c.category.isEmpty ? 'Diziler' : c.category;
        final name = parsed?.series ?? group;
        final series = byName.putIfAbsent(
          name.toLowerCase(),
          () => Series(name: name, category: group, sourceId: sourceId),
        );
        final season = parsed?.season ?? 1;
        final number = parsed?.episode ?? (loose[name] = (loose[name] ?? 0) + 1);
        final title = parsed?.title ?? c.name;
        series._seasons
            .putIfAbsent(season, () => [])
            .add(Episode(channel: c, season: season, number: number, title: title));
      }
    }
    for (final s in byName.values) {
      for (final list in s._seasons.values) {
        list.sort((a, b) => a.number.compareTo(b.number));
      }
    }
    return byName.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
