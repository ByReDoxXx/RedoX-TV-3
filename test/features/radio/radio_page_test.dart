import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/radio/radio_page.dart';
import 'package:redox_tv/features/radio/radio_player_page.dart';
import 'package:redox_tv/features/radio/widgets/radio_options.dart';

import '../../support/fake_radio_audio.dart';
import '../../support/render.dart';

/// Örnek istasyonlar (gerçek liste şifreli pakettedir).
const _names = {
  'Pop': ['Yıldız Pop', 'Mavi Dalga', 'Kıyı Hit', 'Neşeli Pazar', 'Gökyüzü Müzik', 'Akşam Sefası'],
  'Türkü & Halk': ['Anadolu Türküleri', 'Çınar Halk', 'Bozkır FM'],
  'Nostalji': ['Altın Şarkılar', 'Plak 45'],
  'Haber & Spor': ['Gündem Radyo'],
};

final _stations = [
  for (final (i, (genre, name)) in [
    for (final e in _names.entries)
      for (final n in e.value) (e.key, n),
  ].indexed)
    LiveChannel(name: name, number: i + 1, category: genre, streams: ['s$i', if (i.isEven) 's${i}b']),
];

(RadioController, FakeRadioAudio, Favorites) _setup() {
  final audio = FakeRadioAudio();
  final radio = RadioController(stations: ValueNotifier(_stations), audio: () => audio);
  addTearDown(radio.dispose);
  return (radio, audio, Favorites(radios: const [2]));
}

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(FormFactor f, RadioController radio, Favorites fav, {GlobalKey? boundary}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: RadioPage(radio: radio, favorites: fav, clock: '20:45', profileName: 'Profil 1'),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('TV: liste, çipler ve paneller taşmasız; Favoriler çipi süzer', (tester) async {
    await _size(tester, const Size(960, 540));
    final (radio, _, fav) = _setup();
    await tester.pumpWidget(_app(FormFactor.tv, radio, fav));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('ŞİMDİ ÇALIYOR'), findsOneWidget);
    expect(find.text('SEÇİLİ İSTASYON'), findsOneWidget);
    expect(find.text('Yıldız Pop'), findsWidgets);

    await tester.tap(find.text(RadioPage.favoritesFilter));
    await _settle(tester);
    expect(find.text('Mavi Dalga'), findsWidgets);
    expect(find.text('Kıyı Hit'), findsNothing);
  });

  testWidgets('OK istasyonu çalar ve kadranı açar; ◄ ► çevirir, beklenince çalar; ▲ listeye döner, ses sürer', (
    tester,
  ) async {
    await _size(tester, const Size(960, 540));
    final (radio, audio, fav) = _setup();
    await tester.pumpWidget(_app(FormFactor.tv, radio, fav));
    await _settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(find.byType(RadioPlayerPage), findsOneWidget);
    expect(radio.current, _stations.first);
    expect(audio.opened, ['s0']);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(radio.current, _stations.first, reason: 'gezinirken eski istasyon çalar');
    await tester.pump(RadioPlayerPage.tuneDelay);
    expect(radio.current, _stations[1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _settle(tester);
    expect(find.byType(RadioPlayerPage), findsNothing);
    expect(radio.status, RadioStatus.playing);
  });

  testWidgets('seçenekler: uyku zamanlayıcısı ve radyoyu kapat', (tester) async {
    await _size(tester, const Size(960, 540));
    final (radio, _, fav) = _setup();
    await tester.pumpWidget(_app(FormFactor.tv, radio, fav));
    await _settle(tester);
    await radio.play(_stations[3]);
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: Scaffold(
          body: RadioPlayerPage(radio: radio, stations: _stations, favorites: fav),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Seçenekler'));
    await _settle(tester);
    expect(find.byType(RadioOptions), findsOneWidget);
    await tester.tap(find.text('Uyku zamanlayıcı'));
    await tester.pump();
    expect(radio.sleepLeft, isNotNull);
    await tester.tap(find.text('Radyoyu kapat'));
    await _settle(tester);
    expect(radio.status, RadioStatus.idle);
    radio.setSleep(null);
  });

  testWidgets('görüntüler: TV ve telefon (liste, kadran, seçenekler)', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
        // Açık katlanabilir telefon (Pixel 9 Pro Fold iç ekranı): tablet düzeni.
        (FormFactor.tablet, Size(840, 800), 'fold-acik'),
      ]) {
        await _size(tester, size);
        final (radio, audio, fav) = _setup();
        final key = GlobalKey();
        await tester.pumpWidget(_app(f, radio, fav, boundary: key));
        await radio.play(_stations[6]);
        audio.icy = 'Neşet Ertaş - Gönül Dağı';
        await settleAssets(tester, rounds: 3);
        await maybeSnapshot(tester, key, 'build/radyo/$name-1-liste.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);

        // Listedeki ilk satır (ağaçta panelden önce gelir).
        await tester.tap(find.text('Yıldız Pop').first);
        await _settle(tester);
        await settleAssets(tester, rounds: 3);
        await maybeSnapshot(tester, key, 'build/radyo/$name-2-kadran.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);

        await tester.tap(find.bySemanticsLabel('Seçenekler').first);
        await _settle(tester);
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/radyo/$name-3-secenekler.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
