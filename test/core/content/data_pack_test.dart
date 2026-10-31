import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/channel_source.dart';
import 'package:redox_tv/core/content/data_pack.dart';
import 'package:redox_tv/core/content/epg_source.dart';

import '../../support/test_pack.dart';

void main() {
  late TestPack t;
  setUp(() async => t = await TestPack.create());

  Future<void> rejects(Future<Object?> f, String why) =>
      expectLater(f, throwsA(isA<DataPackException>().having((e) => e.message, 'message', contains(why))));

  test('açılır: imza ve şifre tutuyor', () async {
    final bin = await t.seal({'merhaba': 'dünya'}, kind: DataPack.channels);
    expect(await t.reader.open(bin, kind: DataPack.channels), {'merhaba': 'dünya'});
  });

  test('tek bayt değişirse imza tutmaz', () async {
    final bin = await t.seal({'a': 1}, kind: DataPack.channels);
    bin[30] ^= 1;
    await rejects(t.reader.open(bin, kind: DataPack.channels), 'imza');
  });

  test('başka anahtarla imzalanmış paket reddedilir', () async {
    final other = await TestPack.create();
    final bin = await other.seal({'a': 1}, kind: DataPack.channels);
    await rejects(t.reader.open(bin, kind: DataPack.channels), 'imza');
  });

  test('tür karışmaz: EPG paketi kanal diye açılmaz', () async {
    final bin = await t.seal({'a': 1}, kind: DataPack.epg);
    await rejects(t.reader.open(bin, kind: DataPack.channels), 'tür');
  });

  test('şifre anahtarı yoksa ya da yanlışsa açılmaz', () async {
    final bin = await t.seal({'a': 1}, kind: DataPack.channels);
    final noKey = DataPack(dataKey: const [], signPublicKey: t.reader.signPublicKey);
    await rejects(noKey.open(bin, kind: DataPack.channels), 'anahtar');
    final wrongKey = DataPack(dataKey: List.filled(32, 7), signPublicKey: t.reader.signPublicKey);
    await rejects(wrongKey.open(bin, kind: DataPack.channels), 'anahtar');
  });

  test('kısa ya da RDX1 olmayan dosya reddedilir', () async {
    await rejects(t.reader.open([1, 2, 3], kind: DataPack.channels), 'kısa');
    await rejects(t.reader.open(List.filled(200, 0), kind: DataPack.channels), 'RDX1');
  });

  test('redox-epg/tools/pack.mjs ile üretilen paket açılır (Node ↔ Dart)', () async {
    final keys = jsonDecode(File('test/fixtures/test-anahtarlari.json').readAsStringSync()) as Map<String, Object?>;
    final reader = DataPack(
      dataKey: base64.decode(keys['dataKey']! as String),
      signPublicKey: base64.decode(keys['signPublic']! as String),
    );
    final channels = await ChannelSource.open(File('test/fixtures/kanallar.bin').readAsBytesSync(), reader);
    expect(channels.map((c) => (c.number, c.name, c.category)), [
      (3, 'TRT Spor', 'Spor'),
      (6, 'TRT 1', 'Ulusal'),
      (7, 'Numarasız TV', 'Yerel'),
    ]);
    expect(channels[1].streams, ['https://example.invalid/trt1-a.m3u8', 'https://example.invalid/trt1-b.m3u8']);
    expect(channels[1].logoUrl, 'https://example.invalid/trt1.png');
    expect(channels[0].logoUrl, isNull);
  });

  test('uygulamanın gömülü listesi gerçek imza anahtarıyla imzalı', () async {
    // Şifre anahtarı testte yok: imza doğrulanır, çözme anahtar yüzünden durur.
    final bin = File(ChannelSource.asset).readAsBytesSync();
    await rejects(DataPack.app().open(bin, kind: DataPack.channels), 'anahtar');
    final wrongKey = DataPack(dataKey: List.filled(32, 7), signPublicKey: DataPack.app().signPublicKey);
    await rejects(wrongKey.open(bin, kind: DataPack.channels), 'şifre anahtarı tutmuyor');
  });

  test('ChannelSource.fromJson: eksik alanlı kayıt atlanır', () {
    final list = ChannelSource.fromJson({
      'channels': [
        {
          'number': 1,
          'name': 'A',
          'category': 'Ulusal',
          'streams': ['u'],
        },
        {'number': 2, 'name': 'B'},
      ],
    });
    expect(list.map((c) => c.name), ['A']);
  });

  test('EpgSource.fromPack: kaynaklar sırayla birleşir, bozuk kaynak atlanır', () {
    String b64(String xml) => base64.encode(gzip.encode(utf8.encode(xml)));
    String guide(String title) =>
        '<tv><channel id="t"><display-name>TRT 1</display-name></channel>'
        '<programme start="20261031200000 +0300" stop="20261031210000 +0300" channel="t"><title>$title</title></programme></tv>';
    final g = EpgSource.fromPack({
      'sources': [
        {'name': 'bozuk', 'xmltv': b64('<tv')},
        {'name': 'bir', 'xmltv': b64(guide('Birinci'))},
        {'name': 'iki', 'xmltv': b64(guide('İkinci'))},
      ],
    });
    expect(g.of('TRT 1').single.title, 'Birinci');
  });

  test('EpgSource.load: paket inmezse boş akış', () async {
    final g = await EpgSource.load(t.reader, from: 'https://redox.invalid/epg.bin');
    expect(g.channelCount, 0);
  });
}
