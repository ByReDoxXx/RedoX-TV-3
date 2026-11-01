import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/source_receiver.dart';
import 'package:redox_tv/core/content/user_sources.dart';

const _m3u = '''#EXTM3U
#EXTINF:-1 tvg-chno="1" group-title="Spor",Spor Bir
http://ornek/1.m3u8
#EXTINF:-1 tvg-chno="2" group-title="Spor",Spor İki
http://ornek/2.m3u8
''';

Future<Directory> _dir() async {
  final d = await Directory.systemTemp.createTemp('redox-kaynak-');
  addTearDown(() => d.delete(recursive: true));
  return d;
}

void main() {
  test('metin eklenir, kanalları okunur; kayıt yeniden açılınca durur', () async {
    final dir = await _dir();
    final s = await UserSources.open(dir);
    final added = await s.addText('Spor listem', _m3u, origin: SourceOrigin.file);
    expect(added.count, 2);
    expect((await s.channels(added)).map((c) => c.name), ['Spor Bir', 'Spor İki']);

    final again = await UserSources.open(dir);
    expect(again.items.single.name, 'Spor listem');
    expect((await again.channels(again.items.single)).length, 2);
  });

  test('M3U olmayan metin reddedilir', () async {
    final s = await UserSources.open(await _dir());
    expect(() => s.addText('x', '<html></html>', origin: SourceOrigin.file), throwsA(isA<SourceException>()));
    expect(s.items, isEmpty);
  });

  test('adresle eklenir ve yenilenir; ad boşsa dosya adı; silinir', () async {
    var text = _m3u;
    final s = await UserSources.open(await _dir(), fetch: (uri, _) async => utf8.encode(text));
    final added = await s.addUrl('', 'http://ornek.com/listeler/spor.m3u');
    expect(added.name, 'spor');
    expect(added.refreshable, isTrue);

    text = '$_m3u#EXTINF:-1 tvg-chno="3",Üç\nhttp://ornek/3.m3u8\n';
    final refreshed = await s.refresh(added);
    expect(refreshed.count, 3);

    expect(() => s.addUrl('x', 'ftp://ornek'), throwsA(isA<SourceException>()));
    await s.remove(refreshed);
    expect(s.items, isEmpty);
  });

  group('telefondan (QR) ekleme', () {
    late UserSources sources;
    late SourceReceiver receiver;
    late String url;

    setUp(() async {
      sources = await UserSources.open(await _dir());
      receiver = SourceReceiver(sources);
      url = (await receiver.start(host: '127.0.0.1'))!;
      addTearDown(receiver.stop);
    });

    Future<(int, String)> send(String method, String path, {Object? body}) async {
      final client = HttpClient();
      try {
        final req = await client.openUrl(method, Uri.parse(url).replace(path: path));
        if (body != null) {
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(body));
        }
        final res = await req.close();
        return (res.statusCode, await utf8.decodeStream(res));
      } finally {
        client.close();
      }
    }

    test('anahtarsız istek reddedilir; sayfa açılır', () async {
      final client = HttpClient();
      final res = await (await client.getUrl(Uri.parse(url).replace(query: ''))).close();
      expect(res.statusCode, HttpStatus.forbidden);
      client.close();
      final (code, html) = await send('GET', '/');
      expect(code, HttpStatus.ok);
      expect(html, contains("RedoX TV'ye liste ekle"));
    });

    test('dosya metni gönderilince klasör eklenir; geçersizse hata iletisi', () async {
      final (ok, msg) = await send('POST', '/ekle', body: {'name': 'Telefon listesi', 'text': _m3u});
      expect(ok, HttpStatus.ok);
      expect(msg, contains('2 kanal'));
      expect(sources.items.single.origin, SourceOrigin.phone);

      final (bad, err) = await send('POST', '/ekle', body: {'text': 'merhaba'});
      expect(bad, HttpStatus.badRequest);
      expect(err, contains('M3U'));
    });
  });
}
