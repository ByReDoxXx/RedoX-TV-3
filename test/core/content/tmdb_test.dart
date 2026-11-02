import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cleanName: dil öneki, ayraçlar, kalite etiketleri ve yıl ayrılır', () {
    expect(Tmdb.cleanName('TR: Başlangıç (2010) [4K]'), ('Başlangıç', 2010));
    expect(Tmdb.cleanName('|TR| Inception 2010 FHD'), ('Inception', 2010));
    expect(Tmdb.cleanName('The.Matrix.1999.1080p.BluRay'), ('The Matrix', 1999));
    expect(Tmdb.cleanName('Kuzey Güney - Türkçe Dublaj'), ('Kuzey Güney', null));
    expect(Tmdb.cleanName('1917'), ('1917', null));
    expect(Tmdb.cleanName('Film A'), ('Film A', null));
    expect(Tmdb.cleanName('┃MULTI┃ Spider-Man: Brand New Day 4K - 2026'), ('Spider-Man: Brand New Day', 2026));
    expect(Tmdb.cleanName('|MULTI| The Birthday Gift - 2026'), ('The Birthday Gift', 2026));
    expect(Tmdb.cleanName('[NL] |MULTI / LINGO| Tangled'), ('Tangled', null));
  });

  test('find: Türkçe arama, yetki başlığı, önbellek; bulunamayan da saklanır, ağ hatası saklanmaz', () async {
    final asked = <Uri>[];
    var offline = false;
    final tmdb = Tmdb(
      token: 'anahtar',
      fetch: (uri, headers) async {
        expect(headers['Authorization'], 'Bearer anahtar');
        asked.add(uri);
        if (offline) throw Exception('ağ yok');
        final hit = uri.queryParameters['query'] == 'Inception';
        return utf8.encode(
          jsonEncode({
            'results': [
              if (hit)
                {
                  'id': 27205,
                  'title': 'Başlangıç',
                  'overview': 'Rüya içinde rüya.',
                  'release_date': '2010-07-15',
                  'vote_average': 8.37,
                  'poster_path': '/p.jpg',
                  'backdrop_path': '/b.jpg',
                },
            ],
          }),
        );
      },
    );
    final info = (await tmdb.find('TR: Inception (2010) [4K]', series: false))!;
    expect(info.title, 'Başlangıç');
    expect(info.year, 2010);
    expect(info.rating, closeTo(8.37, 1e-9));
    expect(info.poster, 'https://image.tmdb.org/t/p/w342/p.jpg');
    expect(info.backdrop, 'https://image.tmdb.org/t/p/w1280/b.jpg');
    expect(asked.single.path, '/3/search/movie');
    expect(asked.single.queryParameters, {'query': 'Inception', 'language': 'tr-TR', 'year': '2010'});

    await tmdb.find('TR: Inception (2010) [4K]', series: false);
    expect(asked, hasLength(1), reason: 'önbellekten');

    expect(await tmdb.find('Olmayan Dizi', series: true), isNull);
    expect(asked.last.path, '/3/search/tv');
    await tmdb.find('Olmayan Dizi', series: true);
    expect(asked, hasLength(2), reason: 'bulunamayan da saklanır');

    offline = true;
    expect(await tmdb.find('Ağsız', series: false), isNull);
    offline = false;
    await tmdb.find('Ağsız', series: false);
    expect(asked, hasLength(4), reason: 'ağ hatası saklanmaz, yeniden sorulur');

    await Future<void>.delayed(Duration.zero);
    // Önbellek cihazda: yeni nesne aynı adı sormaz.
    final again = Tmdb(token: 'anahtar', fetch: (uri, _) async => fail('sorulmamalı'));
    expect((await again.find('TR: Inception (2010) [4K]', series: false))?.title, 'Başlangıç');
  });
}
