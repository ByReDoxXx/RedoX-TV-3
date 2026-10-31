import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/watch_history.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/story_avatar.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/shell/section_placeholder.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/widgets/epg_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

const _channels = [
  LiveChannel(name: 'TRT 1', number: 6, category: 'Ulusal', streams: ['a', 'b']),
  LiveChannel(
    name: 'TRT Spor',
    number: 3,
    category: 'Spor',
    programTitle: 'Stadyum',
    timeRange: '21:00 – 23:00',
    genre: 'Spor',
    progress: 0.25,
  ),
  LiveChannel(name: 'Show TV', number: 84, category: 'Ulusal'),
];

void main() {
  group('HomeContent.from', () {
    test('geçmiş boşsa ulusal kanallar; vitrin ilk ulusal kanal', () {
      final h = HomeContent.from(channels: _channels, recent: const [], clock: '21:30');
      expect(h.fromHistory, isFalse);
      expect(h.channels.map((c) => c.name), ['TRT 1', 'Show TV']);
      expect(h.hero!.channel.name, 'TRT 1');
      // Yayın akışı yoksa vitrin kanal adını ve bilgi yok yazısını gösterir.
      expect(h.hero!.title, 'TRT 1');
      expect(h.hero!.phase, 'Yayın akışı bilgisi yok');
      expect(h.hero!.clock, '');
      expect(h.hero!.tech, '2 akış');
    });

    test('geçmiş sırasıyla; listede olmayan numara atlanır; vitrin en son izlenen', () {
      final h = HomeContent.from(channels: _channels, recent: const [3, 999, 84], clock: '21:30');
      expect(h.fromHistory, isTrue);
      expect(h.channels.map((c) => c.number), [3, 84]);
      final hero = h.hero!;
      expect(hero.title, 'Stadyum');
      expect(hero.subtitle, 'Spor · Spor · Canlı');
      expect(hero.phase, '21:00 – 23:00');
      expect(hero.clock, '90 dk kaldı');
      expect(hero.progress, 0.25);
    });

    test('kalan süre gece yarısını aşar', () {
      const late = LiveChannel(name: 'X', number: 1, category: 'Ulusal', timeRange: '23:00 – 00:30');
      expect(HomeHero.of(late, nowMinute: 23 * 60 + 50).clock, '40 dk kaldı');
    });

    test('kanal yoksa vitrin de yok', () {
      expect(HomeContent.from(channels: const [], recent: const [], clock: '20:45').hero, isNull);
    });

    test('kısayollar uygulamanın bölümleri', () {
      final h = HomeContent.from(channels: _channels, recent: const [], clock: '20:45');
      expect(h.shortcuts, contains(AppSection.tv));
      expect(h.shortcuts, isNot(contains(AppSection.home)));
    });
  });

  group('WatchHistory', () {
    test('en yeni önde, tekrarsız, en çok 12', () {
      final h = WatchHistory();
      for (var n = 1; n <= 14; n++) {
        h.record(n);
      }
      h.record(5);
      expect(h.value.first, 5);
      expect(h.value, hasLength(WatchHistory.limit));
      expect(h.value.where((n) => n == 5), hasLength(1));
    });

    test('cihazda saklanır ve yeniden okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await WatchHistory.load();
      first
        ..record(6)
        ..record(3);
      await pumpEventQueue();
      final again = await WatchHistory.load();
      expect(again.value, [3, 6]);
    });
  });

  group('Anasayfa düğmeleri', () {
    Future<(WatchHistory, List<FakeEngine>)> open(WidgetTester tester) async {
      await loadSora(tester);
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final history = WatchHistory();
      final engines = <FakeEngine>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: RedoxTheme.dark(),
          home: RootShell(
            tv: const TvContent(channels: _channels),
            history: history,
            // Görüntü kendiliğinden gelmez: geçmişin ne zaman yazıldığı sınanır.
            engineFactory: () => FakeEngine()
              ..autoVideo = false
              ..addTo(engines),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      return (history, engines);
    }

    testWidgets('"Canlı yayına gir" kanalı açar; görüntü gelince geçmişe yazılır', (tester) async {
      final (history, engines) = await open(tester);
      await tester.tap(find.text('Canlı yayına gir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PlayerPage), findsOneWidget);
      expect(engines.single.opened, ['a']);
      expect(history.value, isEmpty, reason: 'görüntü gelmeden yazılmaz');
      engines.single.showVideo();
      await tester.pump();
      expect(history.value, [6]);
    });

    testWidgets('"Yayın akışı" Televizyon sayfasının EPG çizelgesini açar', (tester) async {
      await open(tester);
      await tester.tap(find.text('Yayın akışı'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(EpgGrid), findsOneWidget);
    });

    testWidgets('kısayol halkası bölüme gider', (tester) async {
      await open(tester);
      await tester.tap(find.ancestor(of: find.text('Radyo'), matching: find.byType(StoryAvatar)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SectionPlaceholder), findsOneWidget);
    });
  });
}
