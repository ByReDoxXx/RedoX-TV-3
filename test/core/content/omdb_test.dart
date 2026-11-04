import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/omdb.dart';
import 'package:redox_tv/core/content/stored_api_key.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _film = TmdbInfo(id: 550, title: 'Dövüş Kulübü');

Tmdb _tmdb(List<Uri> asked, {String? imdbId = 'tt0137523'}) => Tmdb(
  token: 'anahtar',
  fetch: (uri, _) async {
    asked.add(uri);
    return utf8.encode(jsonEncode({'imdb_id': imdbId}));
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Omdb.key.current.value = null;
  });

  test('puan: kimlik TMDB\'den, puan OMDb\'den; sonuç saklanır, yeniden sorulmaz', () async {
    final tmdbAsked = <Uri>[];
    final omdbAsked = <Uri>[];
    final omdb = Omdb(
      apiKey: 'abc',
      fetch: (uri) async {
        omdbAsked.add(uri);
        return utf8.encode('{"Response":"True","imdbRating":"8.8","imdbID":"tt0137523"}');
      },
    );
    expect(await omdb.ratingOf(_tmdb(tmdbAsked), _film, series: false), 8.8);
    expect(tmdbAsked.single.path, '/3/movie/550/external_ids');
    expect(omdbAsked.single.host, 'www.omdbapi.com');
    expect(omdbAsked.single.queryParameters, {'i': 'tt0137523', 'apikey': 'abc'});

    // Aynı oturumda ve sonraki açılışta sorgu yok.
    expect(await omdb.ratingOf(_tmdb(tmdbAsked), _film, series: false), 8.8);
    await Future<void>.delayed(Duration.zero);
    final again = Omdb(apiKey: 'abc', fetch: (_) async => fail('sorulmamalı'));
    expect(await again.ratingOf(_tmdb(tmdbAsked), _film, series: false), 8.8);
    expect(tmdbAsked, hasLength(1));
  });

  test('aynı kayıt aynı Future: yeniden çizimde satır titremez', () {
    final omdb = Omdb(apiKey: 'abc', fetch: (_) async => utf8.encode('{"imdbRating":"7.0"}'));
    final tmdb = _tmdb([]);
    expect(identical(omdb.ratingOf(tmdb, _film, series: false), omdb.ratingOf(tmdb, _film, series: false)), isTrue);
  });

  test('dizi ayrı sorulur; N/A ve IMDb kimliği olmayan puansız saklanır', () async {
    final asked = <Uri>[];
    var omdbCalls = 0;
    final omdb = Omdb(
      apiKey: 'abc',
      fetch: (_) async {
        omdbCalls++;
        return utf8.encode('{"Response":"True","imdbRating":"N/A"}');
      },
    );
    expect(await omdb.ratingOf(_tmdb(asked), _film, series: true), isNull);
    expect(asked.single.path, '/3/tv/550/external_ids');
    expect(omdbCalls, 1);

    final noId = Omdb(apiKey: 'abc', fetch: (_) async => fail('kimlik yokken sorulmamalı'));
    const other = TmdbInfo(id: 7, title: 'Kimliksiz');
    expect(await noId.ratingOf(_tmdb(asked, imdbId: null), other, series: false), isNull);
  });

  test('hata saklanmaz, sonra yeniden denenir', () async {
    var fail = true;
    final omdb = Omdb(
      apiKey: 'abc',
      fetch: (_) async {
        if (fail) throw const HttpException('HTTP 401');
        return utf8.encode('{"imdbRating":"6.5"}');
      },
    );
    final tmdb = _tmdb([]);
    expect(await omdb.ratingOf(tmdb, _film, series: false), isNull);
    fail = false;
    expect(await omdb.ratingOf(tmdb, _film, series: false), 6.5);
  });

  test('30 günden eski puan yeniden sorulur; temizlenince de', () async {
    var now = DateTime(2026, 1, 1);
    var calls = 0;
    Omdb make() => Omdb(
      apiKey: 'abc',
      now: () => now,
      fetch: (_) async {
        calls++;
        return utf8.encode('{"imdbRating":"7.5"}');
      },
    );
    final tmdb = _tmdb([]);
    await make().ratingOf(tmdb, _film, series: false);
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(days: 29));
    await make().ratingOf(tmdb, _film, series: false);
    expect(calls, 1);
    now = now.add(const Duration(days: 2));
    final late = make();
    await late.ratingOf(tmdb, _film, series: false);
    expect(calls, 2);
    await late.clearCache();
    await late.ratingOf(tmdb, _film, series: false);
    expect(calls, 3);
  });

  test('anahtar denetimi: 200 geçerli, 401 ret, başka hata ulaşılamadı', () async {
    expect(await Omdb.checkKey('k', fetch: (_) async => utf8.encode('{}')), ApiKeyCheck.valid);
    expect(await Omdb.checkKey('k', fetch: (_) async => throw const HttpException('HTTP 401')), ApiKeyCheck.rejected);
    expect(
      await Omdb.checkKey('k', fetch: (_) async => throw const SocketException('ağ yok')),
      ApiKeyCheck.unreachable,
    );
  });

  test('anahtar saklanır, yüklenir, kaldırılır', () async {
    expect(Omdb.shared, isNull);
    await Omdb.key.set('abc');
    Omdb.key.current.value = null;
    await Omdb.key.load();
    expect(Omdb.shared?.apiKey, 'abc');
    await Omdb.key.set(null);
    await Omdb.key.load();
    expect(Omdb.shared, isNull);
  });
}
