import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/brand/app_info.dart';
import 'package:redox_tv/core/content/app_settings.dart';
import 'package:redox_tv/core/content/backup.dart';
import 'package:redox_tv/core/content/diagnostics.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/playback/playback_session.dart';
import 'package:redox_tv/core/playback/stream_probe.dart';
import 'package:redox_tv/core/playback/subtitle_look.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ayarlar cihazda saklanır; yoksa varsayılanlar', () async {
    final first = await AppSettings.load();
    expect((first.quality, first.failover, first.askProfile), (QualityCap.highest, true, true));
    first
      ..quality = QualityCap.fullHd
      ..scale = StartScale.fill
      ..buffer = BufferSize.s10
      ..failover = false
      ..audio = TrackLanguage.turkish
      ..subtitles = TrackLanguage.off
      ..askProfile = false
      ..startPage = StartPage.lastChannel
      ..textSize = TextSize.large
      ..gestures = false
      ..nightMode = true
      ..backgroundAudio = false
      ..subtitleSize = SubtitleSize.large
      ..subtitleColor = SubtitleColor.yellow
      ..subtitleBackground = SubtitleBackground.none
      ..subtitlePosition = SubtitlePosition.raised
      ..subtitleBold = true;
    await Future<void>.delayed(Duration.zero);
    final again = await AppSettings.load();
    expect(again.quality, QualityCap.fullHd);
    expect(again.scale, StartScale.fill);
    expect(again.buffer.seconds, 10);
    expect(again.failover, isFalse);
    expect(again.audio, TrackLanguage.turkish);
    expect(again.subtitles, TrackLanguage.off);
    expect(again.askProfile, isFalse);
    expect(again.startPage, StartPage.lastChannel);
    expect(again.textSize.scale, 1.15);
    expect((again.gestures, again.nightMode, again.backgroundAudio), (false, true, false));
    expect(
      (again.subtitleSize, again.subtitleColor, again.subtitleBackground, again.subtitlePosition, again.subtitleBold),
      (SubtitleSize.large, SubtitleColor.yellow, SubtitleBackground.none, SubtitlePosition.raised, true),
    );
  });

  test('kalite sınırı: sınırın üstündeki (4K) akış hızlı da olsa sonra gelir', () {
    const fast = Duration(milliseconds: 300);
    final infos = [
      const StreamInfo('4k', latency: fast, bitrate: 25000000),
      const StreamInfo('fhd', latency: fast, bitrate: 8000000),
      const StreamInfo('hd', latency: fast, bitrate: 4000000),
    ];
    expect(StreamProbe.order(infos), ['4k', 'fhd', 'hd']);
    expect(StreamProbe.order(infos, maxBitrate: StreamProbe.capBitrate(QualityCap.fullHd)), ['fhd', 'hd', '4k']);
    expect(StreamProbe.order(infos, maxBitrate: StreamProbe.capBitrate(QualityCap.hd)), ['hd', 'fhd', '4k']);
  });

  test('yedeğe geçiş kapalıysa ilk akış açılmayınca kanal "açılamadı"; elle sonraki akış', () async {
    final engine = FakeEngine()..failing.add('http://a');
    final session = PlaybackSession(
      engine: engine,
      channels: const [
        LiveChannel(name: 'K', number: 1, category: 'Ulusal', streams: ['http://a', 'http://b']),
      ],
      initialIndex: 0,
      failover: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(session.status, PlaybackStatus.failed);
    expect(engine.opened, ['http://a']);
    session.nextStream();
    await Future<void>.delayed(Duration.zero);
    expect(engine.opened.last, 'http://b');
    expect(session.status, PlaybackStatus.playing);
    session.dispose();
  });

  test('yedek: ayarlar ve listeler dosyaya yazılır, geri yüklenir; yabancı dosya reddedilir', () async {
    final dir = await Directory.systemTemp.createTemp('redox-yedek-');
    addTearDown(() => dir.delete(recursive: true));
    SharedPreferences.setMockInitialValues({
      'ayar_kalite': 'fullHd',
      'favori_kanal_p1': ['5', '7'],
      'kilitler': ['kanal:3'],
      'pin_acik': true,
    });
    final sources = await UserSources.open(Directory('${dir.path}/a'));
    await sources.addText('Spor', '#EXTM3U\n#EXTINF:-1,Spor 1\nhttp://s/1.m3u8\n', origin: SourceOrigin.file);
    final text = await Backup.create(sources);
    expect(jsonDecode(text)['bicim'], Backup.format);

    // Başka bir cihaz: boş ayarlar, boş listeler.
    SharedPreferences.setMockInitialValues({'eski': 'silinir'});
    final other = await UserSources.open(Directory('${dir.path}/b'));
    await Backup.restore(text, other);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ayar_kalite'), 'fullHd');
    expect(prefs.getStringList('favori_kanal_p1'), ['5', '7']);
    expect(prefs.getBool('pin_acik'), isTrue);
    expect(prefs.containsKey('eski'), isFalse);
    expect(other.items.single.name, 'Spor');
    expect((await other.channels(other.items.single)).single.name, 'Spor 1');
    expect(() => Backup.restore('{"x":1}', other), throwsFormatException);
    expect(Backup.fileName(DateTime(2026, 3, 4)), 'RedoX-yedek-2026-03-04.json');
  });

  test('tanılama: adresler sunucu adına iner (şifre yazılmaz); en çok 300 satır', () {
    final d = Diagnostics();
    d.log('oynatıcı', 'açılamadı: http://sunucu.tv:8080/live/ali/gizli123/77.ts ve rtmp://x.com/a?token=abc');
    expect(d.lines.single, contains('[oynatıcı] açılamadı: http://sunucu.tv:8080/… ve rtmp://x.com/…'));
    expect(d.lines.single, isNot(contains('gizli123')));
    for (var i = 0; i < 400; i++) {
      d.log('hata', '$i');
    }
    expect(d.lines, hasLength(Diagnostics.limit));
    expect(d.lines.last, endsWith('399'));
    expect(d.report(header: 'RedoX TV').split('\n').first, 'RedoX TV');
  });

  test('altyazı görünümü: boyut, renk, kalınlık; arka plansızken gölge; konum alttan boşluk', () {
    final s = AppSettings(
      subtitleSize: SubtitleSize.larger,
      subtitleColor: SubtitleColor.yellow,
      subtitleBackground: SubtitleBackground.none,
      subtitlePosition: SubtitlePosition.high,
      subtitleBold: true,
    );
    final style = SubtitleLook.style(s);
    expect(style.fontSize, 56);
    expect(style.color, const Color(0xFFFFE14D));
    expect(style.fontWeight, FontWeight.w700);
    expect(style.backgroundColor!.a, 0);
    expect(style.shadows, isNotEmpty);
    expect(SubtitleLook.padding(s).bottom, 140);
    final plain = SubtitleLook.style(AppSettings());
    expect(plain.shadows, isNull);
    expect(plain.backgroundColor, const Color(0xAA000000));
  });

  test('sürüm pubspec ile aynı', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':').last.trim().split('+').first, appVersion);
  });
}
