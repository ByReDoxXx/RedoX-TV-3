import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/remote/remote_client.dart';
import 'package:redox_tv/core/remote/remote_host.dart';
import 'package:redox_tv/core/remote/remote_key.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late RemoteHost host;
  late RemoteClient client;
  late List<RemoteKey> keys;
  late List<String> texts;
  Set<String>? saved;

  setUp(() async {
    keys = [];
    texts = [];
    saved = null;
    host = RemoteHost(
      name: 'Salon TV',
      onKey: keys.add,
      onText: texts.add,
      saveTokens: (t) async => saved = Set.of(t),
      port: 0,
      discoveryPort: 0,
    );
    await host.start();
    client = RemoteClient(discoveryPort: host.boundDiscoveryPort!, broadcast: InternetAddress.loopbackIPv4);
  });

  tearDown(() => host.stop());

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('bulma: yayına TV adı ve HTTP kapısıyla yanıt', () async {
    final found = await client.discover(wait: const Duration(milliseconds: 300));
    expect(found, hasLength(1));
    expect(found.single.name, 'Salon TV');
    expect(found.single.port, host.boundPort);
  });

  test('eşleşme: TV kodu gösterir; yanlış kod reddedilir, doğru kod anahtar verir', () async {
    final tv = RemoteTv(name: 'Salon TV', host: '127.0.0.1', port: host.boundPort!);
    expect(host.pairingCode.value, isNull);
    await client.requestCode(tv);
    final code = host.pairingCode.value!;
    expect(code, matches(RegExp(r'^\d{4}$')));
    final wrong = code == '0000' ? '1111' : '0000';
    await expectLater(client.pair(tv, wrong), throwsA(isA<RemoteCodeException>()));
    final paired = await client.pair(tv, code);
    expect(paired.token, isNotEmpty);
    expect(saved, {paired.token});
    expect(host.pairingCode.value, isNull, reason: 'kod kullanılınca ekrandan kalkar');
  });

  test('5 yanlış kodda kod iptal olur', () async {
    final tv = RemoteTv(name: 'Salon TV', host: '127.0.0.1', port: host.boundPort!);
    await client.requestCode(tv);
    final code = host.pairingCode.value!;
    final wrong = code == '0000' ? '1111' : '0000';
    for (var i = 0; i < 5; i++) {
      await expectLater(client.pair(tv, wrong), throwsA(isA<RemoteCodeException>()));
    }
    expect(host.pairingCode.value, isNull);
    await expectLater(client.pair(tv, code), throwsA(isA<RemoteCodeException>()));
  });

  test('tuşlar anahtarla iletilir; anahtarsız bağlantı reddedilir', () async {
    final tv = RemoteTv(name: 'Salon TV', host: '127.0.0.1', port: host.boundPort!);
    await expectLater(client.connect(tv.withToken('yanlis')), throwsA(isA<WebSocketException>()));
    await client.requestCode(tv);
    final paired = await client.pair(tv, host.pairingCode.value!);
    final c = await client.connect(paired);
    await until(() => host.connected.value == 1);
    expect(host.connected.value, 1);
    c
      ..send(RemoteKey.up)
      ..send(RemoteKey.ok)
      ..send(RemoteKey.digit(7));
    await until(() => keys.length == 3);
    expect(keys, [RemoteKey.up, RemoteKey.ok, RemoteKey.digit7]);
    c.type('Show TV: ilk');
    await until(() => texts.isNotEmpty);
    expect(texts, ['Show TV: ilk']);
    expect(keys, hasLength(3), reason: 'yazı tuş sayılmaz');
    await host.forget();
    await c.done.timeout(const Duration(seconds: 2));
    expect(saved, isEmpty);
  });

  test('son TV saklanır ve silinir', () async {
    SharedPreferences.setMockInitialValues({});
    const tv = RemoteTv(name: 'Salon TV', host: '192.168.1.5', port: 47810, token: 'abc');
    await client.save(tv);
    final back = await client.saved();
    expect((back!.name, back.host, back.port, back.token), ('Salon TV', '192.168.1.5', 47810, 'abc'));
    await client.save(null);
    expect(await client.saved(), isNull);
  });

  test('tuş adları', () {
    expect(RemoteKey.digit(0), RemoteKey.digit0);
    expect(RemoteKey.digit(9), RemoteKey.digit9);
    expect(RemoteKey.byName('channelUp'), RemoteKey.channelUp);
    expect(RemoteKey.byName('yok'), isNull);
  });
}
