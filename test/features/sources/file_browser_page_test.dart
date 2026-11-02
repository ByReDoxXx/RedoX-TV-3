import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/platform/storage_access.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/sources/add_source_tab.dart';
import 'package:redox_tv/features/sources/file_browser_page.dart';

import '../../support/render.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Geçici kök: Listeler/kanallar.m3u, foto.jpg (gizlenir), .gizli (gizlenir).
Future<Directory> _root(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-gezgin-');
  addTearDown(() => dir.delete(recursive: true));
  await Directory('${dir.path}/Listeler').create();
  await File('${dir.path}/Listeler/kanallar.m3u')
      .writeAsString('#EXTM3U\n#EXTINF:-1,Deneme Kanal\nhttp://ornek/d.m3u8\n');
  await File('${dir.path}/foto.jpg').writeAsString('x');
  await Directory('${dir.path}/.gizli').create();
  return dir;
}))!;

Future<void> _tv(WidgetTester tester) async {
  await loadSora(tester);
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  StorageAccess.debugOverride = () async => true;
  addTearDown(() => StorageAccess.debugOverride = null);
}

void main() {
  testWidgets('kökler, klasörler ve yalnız liste dosyaları; Geri üst klasöre; dosya seçilince yolu döner', (
    tester,
  ) async {
    await _tv(tester);
    final root = await _root(tester);
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await Navigator.of(context).push(FileBrowserPage.route(roots: [('Deneme diski', root.path)])),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await _settle(tester);
    expect(find.text('Deneme diski'), findsOneWidget);
    await tester.tap(find.text('Deneme diski'));
    await _settle(tester);
    expect(find.text('Listeler'), findsOneWidget);
    expect(find.text('foto.jpg'), findsNothing);
    expect(find.text('.gizli'), findsNothing);
    await tester.tap(find.text('Listeler'));
    await _settle(tester);
    expect(find.text('kanallar.m3u'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Listeler'), findsOneWidget, reason: 'Geri üst klasöre');
    await tester.tap(find.text('Listeler'));
    await _settle(tester);
    await tester.tap(find.text('kanallar.m3u'));
    await _settle(tester);
    expect(picked, endsWith('kanallar.m3u'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('izin yoksa yönerge ve "İzin ver"', (tester) async {
    await _tv(tester);
    var asked = 0;
    StorageAccess.debugOverride = () async {
      asked++;
      return false;
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: const FileBrowserPage(roots: []),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Tüm dosyalara erişim'), findsOneWidget);
    await tester.tap(find.text('İzin ver'));
    await _settle(tester);
    expect(asked, 2);
  });

  testWidgets('Kaynak ekle › Dosyadan: gezginden seçilen liste eklenir', (tester) async {
    await _tv(tester);
    final root = await _root(tester);
    final sources = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('redox-kaynak-');
      addTearDown(() => dir.delete(recursive: true));
      return UserSources.open(dir);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: Scaffold(
          body: AddSourceTab(sources: sources, fileRoots: [('Deneme diski', root.path)]),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Dosyadan'));
    await _settle(tester);
    await tester.tap(find.text('Deneme diski'));
    await _settle(tester);
    await tester.tap(find.text('Listeler'));
    await _settle(tester);
    await tester.tap(find.text('kanallar.m3u'));
    // Eklenirken dönen gösterge var: pumpAndSettle yerine sabit adımlar.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sources.of(SourceKind.live).map((s) => s.name), contains('kanallar'));
  });
}
