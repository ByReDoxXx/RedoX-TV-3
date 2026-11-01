import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/source_formats.dart';
import 'package:redox_tv/core/content/stalker_client.dart';
import 'package:redox_tv/core/content/user_sources.dart';

const _m3u = '#EXTM3U\n#EXTINF:-1 group-title="Spor",Spor Bir\nhttp://ornek/1.m3u8\n';

Future<Directory> _dir() async {
  final d = await Directory.systemTemp.createTemp('redox-kaynak-');
  addTearDown(() => d.delete(recursive: true));
  return d;
}

void main() {
  group('biçimler', () {
    test('JSON: dizi ya da "channels" anahtarı; yaygın alan adları; adresi olmayan atlanır', () {
      final a = SourceFormats.json(
        jsonEncode([
          {'name': 'Bir', 'url': 'https://a/1.m3u8', 'logo': 'https://a/1.png', 'group': 'Haber'},
          {
            'title': 'İki',
            'streams': ['https://a/2.m3u8', 'https://a/2b.m3u8'],
          },
          {'name': 'Adressiz'},
        ]),
      );
      expect(a.map((c) => c.name), ['Bir', 'İki']);
      expect(a.first.category, 'Haber');
      expect(a.first.logoUrl, 'https://a/1.png');
      expect(a.last.streams, hasLength(2));

      final b = SourceFormats.json(
        jsonEncode({
          'channels': [
            {'channel': 'Üç', 'stream_url': 'http://b/3.ts', 'category': 'Spor'},
          ],
        }),
      );
      expect(b.single.name, 'Üç');
    });

    test('HTML: sayfadaki yayın bağlantıları, bağlantı metni ad olur; göreli adres tamamlanır', () {
      const page = '''<html><body>
        <a href="/canli/trt1.m3u8">TRT 1 Canlı</a>
        <video src="https://cdn.ornek.com/kanal2/index.m3u8?t=1&amp;x=2"></video>
        <a href="/canli/trt1.m3u8">tekrar</a>
      </body></html>''';
      final c = SourceFormats.html(page, base: Uri.parse('https://site.com/sayfa'));
      expect(c, hasLength(2));
      expect(c.first.streams.single, 'https://site.com/canli/trt1.m3u8');
      expect(c.last.streams.single, 'https://cdn.ornek.com/kanal2/index.m3u8?t=1&x=2');
    });

    test('içerikten biçim tanıma; M3U üretimi yeniden okunur', () {
      expect(SourceFormats.detect(_m3u).single.name, 'Spor Bir');
      expect(SourceFormats.detect('[{"name":"A","url":"http://a/1.m3u8"}]').single.name, 'A');
      final back = SourceFormats.detect(SourceFormats.toM3u(SourceFormats.detect(_m3u)));
      expect(back.single.category, 'Spor');
    });
  });

  test('Xtream: hesap doğrulanır, kategoriler ad olur, adres sunucu/live/kullanıcı/şifre/id.biçim', () async {
    final asked = <String>[];
    final s = await UserSources.open(
      await _dir(),
      fetch: (uri, _) async {
        asked.add(uri.queryParameters['action'] ?? 'giris');
        final body = switch (uri.queryParameters['action']) {
          null =>
            uri.queryParameters['password'] == 'dogru'
                ? {
                    'user_info': {
                      'auth': 1,
                      'allowed_output_formats': ['m3u8', 'ts'],
                    },
                  }
                : {
                    'user_info': {'auth': 0},
                  },
          'get_live_categories' => [
            {'category_id': '5', 'category_name': 'Spor'},
          ],
          _ => [
            {'num': 1, 'name': 'Spor 1', 'stream_id': 77, 'category_id': '5', 'stream_icon': 'http://l/1.png'},
          ],
        };
        return utf8.encode(jsonEncode(body));
      },
    );
    expect(
      () => s.addXtream('', server: 'sunucu.com:8080', username: 'ali', password: 'yanlis'),
      throwsA(isA<SourceException>()),
    );
    final added = await s.addXtream('', server: 'sunucu.com:8080/', username: 'ali', password: 'dogru');
    final ch = (await s.channels(added)).single;
    expect(ch.category, 'Spor');
    expect(ch.streams.single, 'http://sunucu.com:8080/live/ali/dogru/77.m3u8');
    expect(added.refreshable, isTrue);
    expect(asked, containsAll(['get_live_categories', 'get_live_streams']));
  });

  test('STB portal: el sıkışma, token başlığı; kanal adresi oynatma anında create_link ile çözülür', () async {
    final headersSeen = <Map<String, String>>[];
    final s = await UserSources.open(
      await _dir(),
      fetch: (uri, headers) async {
        headersSeen.add(headers);
        expect(uri.path, '/stalker_portal/server/load.php');
        final body = switch (uri.queryParameters['action']) {
          'handshake' => {
            'js': {'token': 'ABC'},
          },
          'get_profile' => {'js': {}},
          'get_genres' => {
            'js': [
              {'id': '3', 'title': 'Ulusal'},
            ],
          },
          'get_all_channels' => {
            'js': {
              'data': [
                {
                  'id': '9',
                  'name': 'Kanal Dokuz',
                  'number': '9',
                  'cmd': 'ffrt http://localhost/ch/9',
                  'tv_genre_id': '3',
                },
              ],
            },
          },
          'create_link' => {
            'js': {'cmd': 'ffmpeg http://yayin.ornek/9.ts?token=XYZ'},
          },
          _ => {'js': null},
        };
        return utf8.encode(jsonEncode(body));
      },
    );
    expect(
      () => s.addPortal('', portal: 'http://portal.ornek/stalker_portal/c/', mac: '12345'),
      throwsA(isA<SourceException>()),
    );
    final added = await s.addPortal('', portal: 'http://portal.ornek/stalker_portal/c/', mac: '00:1a:79:aa:bb:cc');
    final ch = (await s.channels(added)).single;
    expect(ch.category, 'Ulusal');
    expect(ch.streams.single, startsWith(StalkerClient.streamPrefix));
    expect(headersSeen.first['Cookie'], contains('mac=00%3A1A%3A79%3AAA%3ABB%3ACC'));
    expect(headersSeen.last['Authorization'], 'Bearer ABC');
    expect(await s.resolve(ch.streams.single), 'http://yayin.ornek/9.ts?token=XYZ');
    expect(await s.resolve('http://olduğu-gibi'), 'http://olduğu-gibi');
  });

  test('Toplu (GitHub): klasördeki .m3u dosyaları ayrı klasör olur; okunamayan sayılır', () async {
    final s = await UserSources.open(
      await _dir(),
      fetch: (uri, _) async {
        if (uri.host == 'api.github.com') {
          expect(uri.path, '/repos/kisi/depo/contents/listeler');
          expect(uri.queryParameters['ref'], 'main');
          return utf8.encode(
            jsonEncode([
              {'name': 'spor.m3u', 'download_url': 'https://raw/spor.m3u'},
              {'name': 'bozuk.m3u8', 'download_url': 'https://raw/bozuk.m3u8'},
              {'name': 'BENIOKU.md', 'download_url': 'https://raw/BENIOKU.md'},
            ]),
          );
        }
        return utf8.encode(uri.path.contains('bozuk') ? 'boş' : _m3u);
      },
    );
    final r = await s.addBulk('https://github.com/kisi/depo/tree/main/listeler');
    expect(r.added.single.name, 'spor');
    expect(r.added.single.origin, SourceOrigin.bulk);
    expect(r.failed, 1);
  });
}
