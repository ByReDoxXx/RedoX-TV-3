import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/app.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:redox_tv/core/content/watch_history.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/playback/frame_grabber.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/features/home/home_page.dart';
import 'package:redox_tv/features/profiles/profile_picker_page.dart';
import 'package:redox_tv/features/profiles/widgets/pin_dialog.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/render.dart';

Future<void> _tv(WidgetTester tester) async {
  await loadSora(tester);
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// İlk kare animasyonu başlatır, ikincisi bitirir (pencere açılış/kapanış).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Kumandanın rakam tuşlarıyla PIN girer.
Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)));
  }
  await _settle(tester);
}

Widget _picker(ProfileStore store, ValueChanged<Profile> onSelected) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: FormFactor.tv),
  home: ProfilePickerPage(store: store, onSelected: onSelected),
);

void main() {
  testWidgets('"Kim izliyor?": profiller, "+" ve odaktaki profilin altında düzenle', (tester) async {
    await _tv(tester);
    await tester.pumpWidget(_picker(ProfileStore(), (_) {}));
    await _settle(tester);
    expect(find.text('Kim izliyor?'), findsOneWidget);
    expect(find.text('Profil 1'), findsOneWidget);
    expect(find.text('Çocuk'), findsOneWidget);
    expect(find.bySemanticsLabel('Ekle'), findsOneWidget);
    expect(find.bySemanticsLabel('Düzenle'), findsOneWidget, reason: 'yalnız odaktaki profilde');
    expect(tester.takeException(), isNull);
  });

  testWidgets('çocuk profili PIN yokken açılırsa PIN iki kez belirlenir', (tester) async {
    await _tv(tester);
    final store = ProfileStore();
    Profile? chosen;
    await tester.pumpWidget(_picker(store, (p) => chosen = p));
    await _settle(tester);
    await tester.tap(find.text('Çocuk'));
    await _settle(tester);
    expect(find.byType(PinDialog), findsOneWidget);

    await _typePin(tester, '1234');
    expect(find.text('PIN\'i tekrar girin'), findsOneWidget);
    await _typePin(tester, '9999');
    expect(find.text('PIN\'ler eşleşmedi, baştan girin.'), findsOneWidget);
    expect(chosen, isNull);

    await _typePin(tester, '1234');
    await _typePin(tester, '1234');
    expect(find.byType(PinDialog), findsNothing);
    expect(chosen?.kids, isTrue);
    expect(store.lastId, 'cocuk');
    expect(await store.checkPin('1234'), isTrue);
  });

  testWidgets('son profil çocuksa yetişkin profili PIN ister; yanlış PIN geçmez', (tester) async {
    await _tv(tester);
    final store = ProfileStore(lastId: 'cocuk');
    await store.setPin('4321');
    Profile? chosen;
    await tester.pumpWidget(_picker(store, (p) => chosen = p));
    await _settle(tester);
    await tester.tap(find.text('Profil 1'));
    await _settle(tester);
    expect(find.byType(PinDialog), findsOneWidget);

    await _typePin(tester, '0000');
    expect(find.text('PIN yanlış.'), findsOneWidget);
    expect(chosen, isNull);

    await _typePin(tester, '4321');
    expect(chosen?.id, 'p1');
    expect(store.lockedToKids, isFalse);
  });

  testWidgets('çocuk profili yeniden seçilirken PIN sorulmaz', (tester) async {
    await _tv(tester);
    final store = ProfileStore(lastId: 'cocuk');
    await store.setPin('4321');
    Profile? chosen;
    await tester.pumpWidget(_picker(store, (p) => chosen = p));
    await _settle(tester);
    await tester.tap(find.text('Çocuk'));
    await _settle(tester);
    expect(find.byType(PinDialog), findsNothing);
    expect(chosen?.kids, isTrue);
  });

  testWidgets('görüntüler: seçim ekranı, PIN ve düzenleyici (TV ve telefon)', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
      ]) {
        await loadSora(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final store = ProfileStore(
          profiles: const [
            Profile(id: 'p1', name: 'Serhat'),
            Profile(id: 'p2', name: 'irem', color: 3),
            Profile(id: 'cocuk', name: 'Çocuk', color: 2, kids: true),
          ],
        );
        await store.setPin('1234');
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: RedoxTheme.dark(formFactor: f),
              home: ProfilePickerPage(store: store, onSelected: (_) {}),
            ),
          ),
        );
        await settleAssets(tester);
        await maybeSnapshot(tester, key, 'build/profiller/$name-1-secim.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);

        await tester.tap(find.bySemanticsLabel('Düzenle'));
        await _settle(tester);
        await maybeSnapshot(tester, key, 'build/profiller/$name-2-pin.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await _typePin(tester, '1234');
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/profiller/$name-3-duzenle.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('uygulama', () {
    WatchHistory Function(String) histories() {
      final cache = <String, WatchHistory>{};
      return (id) => cache[id] ??= WatchHistory(id == 'p1' ? const [24, 42] : const []);
    }

    testWidgets('açılışta seçim ekranı; o sırada Anasayfa kareleri alınır', (tester) async {
      await _tv(tester);
      final grabbed = <String>[];
      final frames = FrameStore(
        grabber: (url) async {
          grabbed.add(url);
          return Uint8List.fromList([0xFF, 0xD8]);
        },
      );
      await tester.pumpWidget(
        RedoxApp(tv: ValueNotifier(TvContent.preview), profiles: ProfileStore(), history: histories(), frames: frames),
      );
      await _settle(tester);
      expect(find.byType(ProfilePickerPage), findsOneWidget);
      expect(find.byType(RootShell), findsNothing);
      final shelf = TvContent.preview.channels.where((c) => const [24, 42].contains(c.number));
      for (final c in shelf) {
        expect(frames.frameOf(c), isNotNull, reason: '${c.name} karesi profil seçilmeden alınır');
      }
      expect(grabbed, isNotEmpty);
    });

    testWidgets('çocuk profili (telefon): yalnız Çocuk kanalları, alt menü yok; "Diğer"den profil değişir', (
      tester,
    ) async {
      await _tv(tester);
      final store = ProfileStore(lastId: 'cocuk');
      await store.setPin('1111');
      await tester.pumpWidget(RedoxApp(tv: ValueNotifier(TvContent.preview), profiles: store, history: histories()));
      await _settle(tester);
      await tester.tap(find.text('Çocuk'));
      await _settle(tester);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(RedoxBottomBar), findsNothing);
      final home = tester.widget<HomePage>(find.byType(HomePage)).content;
      expect(home.channels, isNotEmpty);
      expect(home.channels.every((c) => c.category == Profile.kidsCategory), isTrue);
      expect(home.shortcuts, [AppSection.tv]);

      await tester.tap(find.bySemanticsLabel('Diğer'));
      await _settle(tester);
      expect(find.text('Televizyon'), findsWidgets);
      await tester.tap(find.text('Profil değiştir'));
      await _settle(tester);
      expect(find.byType(ProfilePickerPage), findsOneWidget);
      // Yetişkin profili PIN ister.
      await tester.tap(find.text('Profil 1'));
      await _settle(tester);
      expect(find.byType(PinDialog), findsOneWidget);
    });

    testWidgets('çocuk profili (TV): rayda yalnız Anasayfa ve Televizyon, Ayarlar yok', (tester) async {
      await _tv(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: RedoxTheme.dark(formFactor: FormFactor.tv),
          home: RootShell(tv: TvContent.preview, profile: ProfileStore.defaults.last, onSwitchProfile: () {}),
        ),
      );
      await _settle(tester);
      final rail = tester.widget<RedoxNavRail>(find.byType(RedoxNavRail));
      expect(rail.items.map((i) => i.label), ['Anasayfa', 'Televizyon']);
      expect(rail.footer, isEmpty);
      expect(find.text('Çocuk'), findsWidgets, reason: 'başlıkta profil adı');
    });
  });
}
