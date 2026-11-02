import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/remote/remote_client.dart';
import 'package:redox_tv/core/remote/remote_host.dart';
import 'package:redox_tv/core/remote/remote_key.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/remote/pairing_overlay.dart';
import 'package:redox_tv/features/remote/remote_page.dart';

import '../../support/render.dart';

class _Connection implements RemoteConnection {
  final sent = <RemoteKey>[];
  final typed = <String>[];
  final _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  void send(RemoteKey key) => sent.add(key);

  @override
  void type(String text) => typed.add(text);

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }
}

class _Client extends RemoteClient {
  _Client({this.stored});

  RemoteTv? stored;
  final connection = _Connection();
  var codeRequests = 0;
  static const tv = RemoteTv(name: 'Salon TV', host: '192.168.1.5', port: 47810);

  @override
  Future<RemoteTv?> saved() async => stored;

  @override
  Future<void> save(RemoteTv? tv) async => stored = tv;

  @override
  Future<List<RemoteTv>> discover({Duration wait = Duration.zero}) async => [tv];

  @override
  Future<void> requestCode(RemoteTv tv) async => codeRequests++;

  @override
  Future<RemoteTv> pair(RemoteTv tv, String code) async =>
      code == '1234' ? tv.withToken('anahtar') : throw const RemoteCodeException();

  @override
  Future<RemoteConnection> connect(RemoteTv tv) async => connection;
}

Finder _key(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.button == true && w.properties.label == label);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Future<void> _phone(WidgetTester tester) async {
  await loadSora(tester);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(Widget page, {FormFactor f = FormFactor.phone}) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: f),
  home: page,
);

void main() {
  testWidgets('ilk açılış: TV bulunur, kod girilir, kumanda ekranı doldurur ve tuş gönderir', (tester) async {
    await _phone(tester);
    final client = _Client();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(RemotePage(client: client)),
      ),
    );
    await _settle(tester);
    expect(find.text('Salon TV'), findsOneWidget);
    await tester.tap(find.text('Salon TV'));
    await _settle(tester);
    expect(client.codeRequests, 1);
    expect(find.textContaining('4 haneli kodu girin'), findsOneWidget);

    for (final d in ['9', '9', '9', '9']) {
      await tester.tap(_key(d));
      await _settle(tester);
    }
    expect(find.text('Kod yanlış. TV ekranındaki kodu girin.'), findsOneWidget);
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(_key(d));
      await _settle(tester);
    }
    expect(tester.takeException(), isNull);
    expect(client.stored?.token, 'anahtar');
    expect(_key('Tamam'), findsOneWidget);
    await settleAssets(tester, rounds: 4);
    await maybeSnapshot(tester, key, 'build/kumanda/telefon-kumanda.png', pixelRatio: 2);

    for (final label in ['Yukarı', 'Tamam', 'Geri', 'Ana sayfa', 'Sesi artır', 'Sonraki kanal', 'Oynat/Duraklat']) {
      await tester.tap(_key(label));
    }
    await tester.tap(_key('Rakamlar'));
    await tester.pump();
    await tester.tap(_key('5'));
    expect(client.connection.sent, [
      RemoteKey.up,
      RemoteKey.ok,
      RemoteKey.back,
      RemoteKey.home,
      RemoteKey.volumeUp,
      RemoteKey.channelUp,
      RemoteKey.playPause,
      RemoteKey.digit5,
    ]);

    await tester.tap(_key('Klavye'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kuzey güney');
    await tester.tap(_key('Gönder'));
    await tester.pumpAndSettle();
    expect(client.connection.typed, ['kuzey güney']);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('kayıtlı TV: doğrudan bağlanır; "TV değiştir" eşleşmeyi siler', (tester) async {
    await _phone(tester);
    final client = _Client(stored: _Client.tv.withToken('anahtar'));
    await tester.pumpWidget(_app(RemotePage(client: client)));
    await _settle(tester);
    expect(_key('Tamam'), findsOneWidget);
    expect(find.text('Salon TV'), findsOneWidget);
    await tester.tap(_key('TV değiştir'));
    await _settle(tester);
    expect(client.stored, isNull);
    expect(find.text("Yerel ağdaki TV'ler"), findsOneWidget);
  });

  testWidgets('TV: eşleşme kodu her ekranın üstünde görünür', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = RemoteHost(name: 'Salon TV', onKey: (_) {});
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: RedoxTheme.dark(formFactor: FormFactor.tv),
          builder: (context, child) => PairingOverlay(host: host, child: child!),
          home: const Scaffold(body: Center(child: Text('Anasayfa'))),
        ),
      ),
    );
    expect(find.text('Telefon kumandası'), findsNothing);
    host.pairingCode.value = '4821';
    await tester.pump();
    expect(find.text('4 8 2 1'), findsOneWidget);
    await settleAssets(tester, rounds: 4);
    await maybeSnapshot(tester, key, 'build/kumanda/tv-kod.png', pixelRatio: 2);
    host.pairingCode.value = null;
    await tester.pump();
    expect(find.text('Telefon kumandası'), findsNothing);
  });
}
