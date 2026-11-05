import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/content_locks.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/platform/system_text_input.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/locks/lock_scope.dart';
import 'package:redox_tv/features/sources/source_search.dart';
import 'package:redox_tv/features/sources/sources_page.dart';
import 'package:redox_tv/features/sources/widgets/source_widgets.dart';

import '../../support/render.dart';

String _m3u(List<String> names, String group) => [
  '#EXTM3U',
  for (final (i, n) in names.indexed) ...['#EXTINF:-1 group-title="$group",$n', 'http://ornek/$group$i.mp4'],
].join('\n');

Future<UserSources> _sources(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-kaynak-ara-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  await s.addText('Spor listem', _m3u(['Şampiyonlar Ligi', 'Tenis'], 'Spor'), origin: SourceOrigin.url);
  await s.addText(
    'Filmlerim',
    _m3u(['Başlangıç (2010)', 'Yıldızlararası'], 'Bilim'),
    origin: SourceOrigin.file,
    kind: SourceKind.film,
  );
  return s;
}))!;

Widget _page(
  FormFactor f,
  UserSources s, {
  ContentLocks? locks,
  Future<void> Function(List<LiveChannel>, int)? onWatch,
  GlobalKey? boundary,
}) {
  final page = SourcesPage(sources: s, clock: '20:45', profileName: 'Profil 1', onAdd: () {}, onWatch: onWatch);
  return RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: f),
      home: Scaffold(
        body: locks == null ? page : LockScope(locks: locks, profiles: null, child: page),
      ),
    ),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Gecikme ve liste dosyasının okunması bitsin.
Future<void> _scan(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

void main() {
  group('SourceSearch', () {
    testWidgets('Türkçe harf ayrımı yok; tür süzülür; iptal edilince boş', (tester) async {
      final s = await _sources(tester);
      final search = SourceSearch(s);
      Future<List<SourceHit>> run(String q, {SourceKind? kind, bool Function()? cancelled}) async =>
          (await tester.runAsync(() => search.run(q, kind: kind, cancelled: cancelled)))!;

      expect((await run('sampiyon')).single.channel.name, 'Şampiyonlar Ligi');
      expect((await run('YILDIZ')).single.channel.name, 'Yıldızlararası');
      final hit = (await run('tenis')).single;
      expect(hit.list[hit.index].name, 'Tenis');
      expect(await run('tenis', kind: SourceKind.film), isEmpty);
      expect(await run('   '), isEmpty);
      expect(await run('tenis', cancelled: () => true), isEmpty);
    });

    testWidgets('kilitli kaynağın, klasörün ve kaydın içi aranmaz', (tester) async {
      final s = await _sources(tester);
      final search = SourceSearch(s);
      final spor = s.of(SourceKind.live).single;
      Future<List<SourceHit>> run(ContentLocks locks) async =>
          (await tester.runAsync(() => search.run('tenis', locks: locks)))!;

      expect(await run(ContentLocks()), hasLength(1));
      expect(await run(ContentLocks({ContentLocks.folder(spor.id, const [])})), isEmpty);
      expect(
        await run(
          ContentLocks({
            ContentLocks.folder(spor.id, ['Spor']),
          }),
        ),
        isEmpty,
      );
      expect(await run(ContentLocks({ContentLocks.item('http://ornek/Spor1.mp4')})), isEmpty);
    });
  });

  testWidgets('telefon: yazdıkça liste ve içerik bulunur, kayıt oynar, temizleyince listeler döner', (tester) async {
    await _size(tester, const Size(412, 915));
    final s = await _sources(tester);
    List<LiveChannel>? watched;
    int? at;
    await tester.pumpWidget(
      _page(
        FormFactor.phone,
        s,
        onWatch: (list, i) async {
          watched = list;
          at = i;
        },
      ),
    );
    await _scan(tester);
    expect(find.text('2 liste · 4 kayıt'), findsOneWidget);
    expect(find.text('Canlı TV'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'yildiz');
    await _scan(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Yıldızlararası'), findsOneWidget);
    expect(find.text('Filmlerim · Bilim'), findsOneWidget);
    expect(find.text('Spor listem'), findsNothing);
    await tester.tap(find.text('Yıldızlararası'));
    expect(watched![at!].name, 'Yıldızlararası');

    await tester.enterText(find.byType(TextField), 'filmler');
    await _scan(tester);
    expect(find.text('Filmlerim'), findsOneWidget, reason: 'liste adı da aranır');
    expect(find.text('Listeler'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'yokboyle');
    await _scan(tester);
    expect(find.textContaining('için sonuç yok'), findsOneWidget);
    await tester.tap(find.text('Aramayı temizle'));
    await tester.pump();
    expect(find.text('Spor listem'), findsOneWidget);
    expect(find.text('Filmlerim'), findsOneWidget);
  });

  testWidgets('TV: Ara düğmesi cihazın klavyesini açar; kilitli listede kilit görünür, içi aranmaz', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester);
    final asked = <String>[];
    SystemTextInput.debugOverride = (title, value, kind) async {
      asked.add(title);
      return 'tenis';
    };
    addTearDown(() => SystemTextInput.debugOverride = null);
    final locks = ContentLocks({ContentLocks.folder(s.of(SourceKind.live).single.id, const [])});
    await tester.pumpWidget(_page(FormFactor.tv, s, locks: locks));
    await _scan(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byWidgetPredicate((w) => w is FolderCard && w.locked), findsOneWidget);

    await tester.tap(find.text('Ara'));
    await _scan(tester);
    expect(asked, ['Kaynaklarda ara']);
    expect(find.text('tenis'), findsOneWidget, reason: 'düğme aranan metni gösterir');
    expect(find.text('Tenis'), findsNothing);
    expect(find.textContaining('için sonuç yok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boşken yönerge ve ekleme düğmesi; arama yok', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('redox-kaynak-bos-');
      addTearDown(() => dir.delete(recursive: true));
      return UserSources.open(dir);
    }))!;
    await tester.pumpWidget(_page(FormFactor.tv, s));
    await tester.pump();
    expect(find.text('Henüz liste yok'), findsOneWidget);
    expect(find.text('Kaynak ekle'), findsOneWidget);
    expect(find.text('Ara'), findsNothing);
  });

  testWidgets('görüntüler: taşma yok', (tester) async {
    for (final (name, f, size) in const [
      ('tv', FormFactor.tv, Size(960, 540)),
      ('tablet', FormFactor.tablet, Size(1280, 800)),
      ('telefon', FormFactor.phone, Size(412, 915)),
    ]) {
      await _size(tester, size);
      final s = await _sources(tester);
      final key = GlobalKey();
      await tester.pumpWidget(_page(f, s, boundary: key));
      await _scan(tester);
      expect(tester.takeException(), isNull, reason: name);
      await maybeSnapshot(tester, key, 'build/kaynaklar/$name-0-listeler.png', pixelRatio: 2);

      if (f == FormFactor.tv) {
        SystemTextInput.debugOverride = (_, _, _) async => 'i';
        addTearDown(() => SystemTextInput.debugOverride = null);
        await tester.tap(find.text('Ara'));
      } else {
        await tester.enterText(find.byType(TextField), 'i');
      }
      await _scan(tester);
      expect(tester.takeException(), isNull, reason: '$name arama');
      await maybeSnapshot(tester, key, 'build/kaynaklar/$name-5-arama.png', pixelRatio: 2);
    }
  });
}
