import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/series_catalog.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/search_scope.dart';
import 'package:redox_tv/core/platform/system_text_input.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/header_search.dart';
import 'package:redox_tv/features/search/library_search.dart';
import 'package:redox_tv/features/search/search_page.dart';

const _channels = [
  LiveChannel(name: 'TRT Çocuk', number: 4, category: 'Çocuk'),
  LiveChannel(name: 'TRT 1', number: 1, category: 'Ulusal', programTitle: 'Gönül Dağı'),
  LiveChannel(name: 'Show TV', number: 8, category: 'Ulusal', programTitle: 'Kızılcık Şerbeti'),
];

void main() {
  group('SearchPage.match', () {
    test('Türkçe harfler sadeleşir, büyük-küçük harf fark etmez', () {
      expect(SearchPage.match(_channels, 'trt cocuk').map((c) => c.name), ['TRT Çocuk']);
      expect(SearchPage.match(_channels, 'TRT').map((c) => c.name), ['TRT Çocuk', 'TRT 1']);
    });

    test('şimdiki programda da arar; adı eşleşenler önde', () {
      expect(SearchPage.match(_channels, 'gönül').map((c) => c.name), ['TRT 1']);
      expect(SearchPage.match(_channels, 'kizilcik').map((c) => c.name), ['Show TV']);
    });

    test('boş sorgu sonuç vermez', () {
      expect(SearchPage.match(_channels, '  '), isEmpty);
    });
  });

  testWidgets('telefonda arama düğmesi arama sayfasını açar (önceden işlevsizdi)', (tester) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.phone),
        home: SearchScope(
          open: (_, q) => opened = q,
          child: const Scaffold(body: Center(child: HeaderSearch())),
        ),
      ),
    );
    await tester.tap(find.byType(HeaderSearch));
    expect(opened, '');
  });

  testWidgets('sonuca dokununca kanal açılır', (tester) async {
    LiveChannel? watched;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.phone),
        home: SearchPage(channels: _channels, initialQuery: 'show', onChannel: (c) => watched = c),
      ),
    );
    await tester.pump();
    expect(find.text('Kanallar (1)'), findsOneWidget);
    await tester.tap(find.text('Show TV'));
    expect(watched?.name, 'Show TV');
  });

  testWidgets('TV: boş açılınca cihazın klavyesi (yerel kutu) gelir; yazılan aranır, OK yeniden açar', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final answers = ['trt', 'show'];
    final values = <String>[];
    SystemTextInput.debugOverride = (title, value, kind) async {
      values.add(value);
      return answers.removeAt(0);
    };
    addTearDown(() => SystemTextInput.debugOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: const SearchPage(channels: _channels),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Kanallar (2)'), findsOneWidget);
    await tester.tap(find.text('trt'));
    await tester.pump();
    await tester.pump();
    expect(values, ['', 'trt'], reason: 'ikinci açılışta yazılan metinle');
    expect(find.text('Kanallar (1)'), findsOneWidget);
  });

  testWidgets('Film ve Dizi sonuçları listelenir; filme basınca film, diziye basınca dizi açılır', (tester) async {
    final sources = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('redox-arama-');
      addTearDown(() => dir.delete(recursive: true));
      final s = await UserSources.open(dir);
      await s.addText(
        'Filmler',
        '#EXTM3U\n#EXTINF:-1 group-title="Aksiyon",The Flash (2023)\nhttp://o/f.mkv\n',
        origin: SourceOrigin.file,
        kind: SourceKind.film,
      );
      await s.addText(
        'Diziler',
        '#EXTM3U\n#EXTINF:-1,The Flash S01E01\nhttp://o/d.mkv\n',
        origin: SourceOrigin.file,
        kind: SourceKind.series,
      );
      return s;
    }))!;
    final library = (await tester.runAsync(() => LibrarySearch.load(sources)))!;
    LiveChannel? film;
    Series? series;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.phone),
        home: SearchPage(
          channels: _channels,
          initialQuery: 'flash',
          library: Future.value(library),
          onFilm: (f, _) => film = f,
          onSeries: (s) => series = s,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Filmler (1)'), findsOneWidget);
    expect(find.text('Diziler (1)'), findsOneWidget);
    expect(find.text('The Flash (2023)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('The Flash (2023)'));
    expect(film?.streams.single, 'http://o/f.mkv');
    await tester.tap(find.text('The Flash'));
    expect(series?.name, 'The Flash');
  });
}
