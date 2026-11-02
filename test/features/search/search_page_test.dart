import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/search_scope.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/header_search.dart';
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
}
