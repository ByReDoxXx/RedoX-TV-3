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
    expect(find.text('Deneme diski'), findsWidgets);
    await tester.tap(find.text('Deneme diski').first);
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
    await tester.ensureVisible(find.text('Dosyadan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dosyadan'));
    await _settle(tester);
    await tester.tap(find.text('Deneme diski').first);
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

  testWidgets('Kaynak ekle › Klasörden: klasör seçilir, videoları Dizi olarak eklenir', (tester) async {
    await _tv(tester);
    final root = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('redox-ssd-');
      addTearDown(() => dir.delete(recursive: true));
      for (final rel in ['Diziler/Arrow/Sezon 1/01.mkv', 'Diziler/Arrow/Sezon 1/02.mkv', 'Diziler/notlar.txt']) {
        final f = File('${dir.path}/$rel');
        await f.parent.create(recursive: true);
        await f.writeAsString('x');
      }
      return dir;
    }))!;
    final sources = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('redox-kaynak-');
      addTearDown(() => dir.delete(recursive: true));
      return UserSources.open(dir);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: Scaffold(
          body: AddSourceTab(sources: sources, fileRoots: [('Harici SSD', root.path)]),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Dizi'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Klasörden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Klasörden'));
    await _settle(tester);
    expect(find.text('Klasör seç'), findsOneWidget);
    await tester.tap(find.text('Harici SSD').first);
    await _settle(tester);
    await tester.tap(find.text('Diziler'));
    await _settle(tester);
    expect(find.text('notlar.txt'), findsNothing, reason: 'klasör kipinde yalnız klasörler ve videolar');
    await tester.tap(find.text('Bu klasörü ekle'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final added = sources.of(SourceKind.series).single;
    expect((added.name, added.count), ('Diziler', 2));
    final eps = (await tester.runAsync(() => sources.channels(added)))!;
    expect(eps.map((c) => c.name), ['Arrow S01E01', 'Arrow S01E02']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('görüntü: TV ve telefon, klasör kipi (konumlar, konum yolu, videolar)', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
      ]) {
        await _tv(tester);
        tester.view.physicalSize = size;
        final (internal, ssd) = (await tester.runAsync(() async {
          final a = await Directory.systemTemp.createTemp('redox-dahili-');
          final b = await Directory.systemTemp.createTemp('redox-ssd-');
          addTearDown(() async {
            await a.delete(recursive: true);
            await b.delete(recursive: true);
          });
          for (final rel in [
            'Filmler/Aksiyon/Mad Max (2015).mkv',
            'Filmler/Oppenheimer (2023).mkv',
            'Filmler/Dune (2021).mp4',
            'Filmler/Başlangıç (2010).avi',
            'Filmler/Belgeseller/Doğa.mov',
          ]) {
            final file = File('${b.path}/$rel');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(List.filled(rel.length * 37000, 0));
          }
          await Directory('${b.path}/Diziler').create();
          return (a, b);
        }))!;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: RedoxTheme.dark(formFactor: f),
              home: FileBrowserPage(
                folder: true,
                roots: [('Dahili depolama', internal.path), ('USB / SD kart (6AE9-B46A)', ssd.path)],
              ),
            ),
          ),
        );
        await _settle(tester);
        await tester.tap(find.text('USB / SD kart (6AE9-B46A)').first);
        await _settle(tester);
        await tester.tap(find.text('Filmler').first);
        // Dosya boyutları da okunur: birkaç tur bekle.
        for (var i = 0; i < 3; i++) {
          await _settle(tester);
        }
        expect(find.text('Oppenheimer (2023).mkv'), findsOneWidget);
        expect(find.text('Bu klasörü ekle'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await maybeSnapshot(tester, key, 'build/gezgin/$name-klasor.png', pixelRatio: 2);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
