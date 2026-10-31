import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/xmltv.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/tv_guide_controller.dart';

const _m3u = '''#EXTM3U
#EXTINF:-1 tvg-id="redox-6" tvg-chno="6" group-title="Ulusal",TRT 1
https://example.invalid/trt1.m3u8
#EXTINF:-1 tvg-id="redox-170" tvg-chno="170" group-title="Spor",FB TV
https://example.invalid/fb.m3u8
#EXTINF:-1 tvg-id="redox-24" tvg-chno="24" group-title="Yerel",Kanal 3 Afyon
https://example.invalid/k3.m3u8
''';

/// Yerel saatle: 31 Ekim 2026, 20:00–21:00 haber, 21:00–23:00 dizi, ertesi
/// gün 00:30–01:00 gece programı.
EpgGuide _guide() {
  DateTime t(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);
  return EpgGuide({
    EpgGuide.key('TRT 1'): [
      GuideEntry(title: 'Ana Haber', start: t(31, 20), stop: t(31, 21), category: 'Haber'),
      GuideEntry(title: 'Dizi', start: t(31, 21), stop: t(31, 23)),
      GuideEntry(title: 'Gece', start: DateTime(2026, 11, 1, 0, 30), stop: DateTime(2026, 11, 1, 1)),
    ],
    EpgGuide.key('FENERBAHÇE TV'): [GuideEntry(title: 'Maç Özeti', start: t(31, 20), stop: t(31, 22))],
  });
}

/// Kanalı adıyla bulur (ayrıştırıcı numaraya göre sıralar).
LiveChannel Function(String) _named(TvContent tv) =>
    (name) => tv.channels.firstWhere((c) => c.name == name);

void main() {
  final base = TvContent.fromM3u(_m3u);
  final now = DateTime(2026, 10, 31, 20, 15);

  test('withGuide: şimdiki program, saat, tür, ilerleme ve sonraki dolar', () {
    final tv = base.withGuide(_guide(), now);
    final trt = tv.channels.first;
    expect(trt.programTitle, 'Ana Haber');
    expect(trt.timeRange, '20:00 – 21:00');
    expect(trt.genre, 'Haber');
    expect(trt.progress, closeTo(0.25, 1e-9));
    expect(trt.next, '21:00 Dizi');
    expect(tv.nowMinute, 20 * 60 + 15);
  });

  test('withGuide: farklı adlı kanal takma adla eşleşir; akışsız kanal boş kalır', () {
    final ch = _named(base.withGuide(_guide(), now));
    expect(ch('FB TV').programTitle, 'Maç Özeti');
    expect(ch('FB TV').next, isNull);
    expect(ch('Kanal 3 Afyon').programTitle, isNull);
    expect(ch('Kanal 3 Afyon').progress, isNull);
  });

  test('withGuide: aynı kanal yeni nesne olur ama eşit sayılır', () {
    final tv = base.withGuide(_guide(), now);
    expect(identical(tv.channels.first, base.channels.first), isFalse);
    expect(tv.channels.first, base.channels.first);
    expect(tv.channels.indexOf(base.channels[1]), 1);
  });

  test('withGuide: program aralığında değilse bilgi boşalır', () {
    final tv = base.withGuide(_guide(), DateTime(2026, 10, 31, 23, 30));
    expect(tv.channels.first.programTitle, isNull);
  });

  test('scheduleOf: günbaşından dakika; gece yarısı sonrası 1440\'ı aşar', () {
    final tv = base.withGuide(_guide(), now);
    final s = tv.scheduleOf(tv.channels.first);
    expect(s.map((p) => (p.title, p.start, p.end)), [
      ('Ana Haber', 1200, 1260),
      ('Dizi', 1260, 1380),
      ('Gece', 1470, 1500),
    ]);
    expect(s.first.isLiveAt(tv.nowMinute!), isTrue);
  });

  test('scheduleOf: akışta olmayan kanal "bilgi yok"', () {
    final tv = base.withGuide(_guide(), now);
    final s = tv.scheduleOf(_named(tv)('Kanal 3 Afyon'));
    expect(s, hasLength(1));
    expect(s.single.known, isFalse);
  });

  group('TvGuideController', () {
    test('açılışta akışı indirir ve kanalları doldurur', () async {
      final c = TvGuideController(base, load: () async => _guide(), clock: () => now);
      await c.start();
      expect(c.value.channels.first.programTitle, 'Ana Haber');
      expect(c.value.now, now);
      c.dispose();
    });

    test('indirme boş dönerse liste akışsız kalır ama saat işler', () async {
      final c = TvGuideController(base, load: () async => EpgGuide.empty, clock: () => now);
      await c.start();
      expect(c.value.channels.first.programTitle, isNull);
      expect(c.value.nowMinute, 20 * 60 + 15);
      c.dispose();
    });

    test('güncel kanal listesi gelince liste değişir, akış yeni listeye uygulanır', () async {
      final fresh = TvContent.fromM3u('''#EXTM3U
#EXTINF:-1 tvg-chno="6" group-title="Ulusal",TRT 1
https://example.invalid/yeni.m3u8
''').channels;
      final c = TvGuideController(base, load: () async => _guide(), loadChannels: () async => fresh, clock: () => now);
      await c.start();
      expect(c.value.channels.map((ch) => ch.name), ['TRT 1']);
      expect(c.value.channels.single.streams, ['https://example.invalid/yeni.m3u8']);
      expect(c.value.channels.single.programTitle, 'Ana Haber');
      c.dispose();
    });

    test('kanal listesi inmezse eldeki kalır', () async {
      final c = TvGuideController(base, load: () async => _guide(), loadChannels: () async => null, clock: () => now);
      await c.start();
      expect(c.value.channels, hasLength(3));
      c.dispose();
    });

    test('kapatıldıktan sonra gelen akış yok sayılır', () async {
      final c = TvGuideController(base, load: () async => _guide(), clock: () => now);
      final done = c.start();
      c.dispose();
      await done;
    });
  });
}
