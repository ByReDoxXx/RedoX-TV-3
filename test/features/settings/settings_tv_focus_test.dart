import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/app_settings.dart';
import 'package:redox_tv/core/content/content_locks.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/remote/remote_host.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/locks/lock_scope.dart';
import 'package:redox_tv/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render.dart';

/// Ayarlar, TV'de kumandayla (TV'de görülen hatalar): ◄ sağ bölmeden seçili
/// bölüme döner (hizadaki satıra değil), son ayardan ▼ soldaki listeye
/// atlamaz, satıra gelince bölüm açılır. REDOX_SNAPSHOT=1: build/ayarlar-tv/.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('TV: Ayarlar kumandayla gezilir', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('redox-ayar-tv-')))!;
    addTearDown(() => dir.delete(recursive: true));
    final sources = (await tester.runAsync(() => UserSources.open(dir)))!;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: RedoxTheme.dark(formFactor: FormFactor.tv),
          home: Scaffold(
            body: LockScope(
              locks: ContentLocks(),
              profiles: null,
              child: SettingsPage(
                sources: sources,
                clock: '20:45',
                profileName: 'Profil 1',
                profiles: ProfileStore(),
                settings: AppSettings(),
                remote: RemoteHost(name: 'Salon TV', onKey: (_) {}, tokens: const {'a'}),
              ),
            ),
          ),
        ),
      ),
    );
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    /// Odaktaki öğenin ilk yazısı.
    String focused() {
      String? text;
      void visit(Element e) {
        if (text != null) return;
        if (e.widget case Text(:final data?)) text = data;
        e.visitChildren(visit);
      }

      (FocusManager.instance.primaryFocus!.context! as Element).visitChildren(visit);
      return text ?? '';
    }

    Future<void> press(LogicalKeyboardKey k, [int times = 1]) async {
      for (var i = 0; i < times; i++) {
        await tester.sendKeyEvent(k);
        await settle();
      }
    }

    await settle();
    expect(focused(), 'Kaynak ekle');
    // ▼ ile satıra gelince bölüm açılır.
    await press(LogicalKeyboardKey.arrowDown, 2);
    expect(focused(), 'Altyazı');
    expect(find.text('Yazı rengi'), findsOneWidget);
    // ► bölmenin ilk ayarı; ▼ ve ◄ seçili bölüme döner.
    await press(LogicalKeyboardKey.arrowRight);
    expect(focused(), 'Otomatik');
    await press(LogicalKeyboardKey.arrowDown);
    expect(focused(), 'Küçük');
    await maybeSnapshot(tester, key, 'build/ayarlar-tv/altyazi.png', pixelRatio: 2);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'Altyazı');

    // Telefon kumandası: son ayardan ▼ yerinde kalır.
    await press(LogicalKeyboardKey.arrowDown, 4);
    expect(focused(), 'Telefon kumandası');
    await press(LogicalKeyboardKey.arrowRight);
    await press(LogicalKeyboardKey.arrowDown, 3);
    expect(focused(), 'Eşleşmeleri unut');
    await maybeSnapshot(tester, key, 'build/ayarlar-tv/kumanda.png', pixelRatio: 2);
    await press(LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'Telefon kumandası');
    expect(tester.takeException(), isNull);
  });
}
