import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/song_history.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';

import '../../support/fake_radio_audio.dart';

const _a = LiveChannel(name: 'A FM', number: 1, category: 'Pop', streams: ['a1']);
const _b = LiveChannel(name: 'B Radyo', number: 2, category: 'Pop', streams: ['b1']);

void main() {
  test('en yenisi önde, en çok 15; art arda aynı şarkı bir kez', () {
    final h = SongHistory();
    for (var i = 1; i <= 17; i++) {
      h.record('Şarkı $i', station: 'A FM', stationNumber: 1);
      h.record('Şarkı $i', station: 'A FM', stationNumber: 1);
    }
    expect(h.value, hasLength(SongHistory.limit));
    expect(h.value.first.title, 'Şarkı 17');
    expect(h.value.last.title, 'Şarkı 3');
  });

  test('boş başlık ve istasyon adı şarkı sayılmaz', () {
    final h = SongHistory()
      ..record('  ', station: 'A FM', stationNumber: 1)
      ..record('a fm', station: 'A FM', stationNumber: 1);
    expect(h.value, isEmpty);
  });

  test('saklama: kayıt sonrası liste kaydedilir; JSON gidiş-dönüş', () {
    List<SongEntry>? saved;
    final h = SongHistory(const [], (l) async => saved = l)
      ..record('Gidiyorum', station: 'A FM', stationNumber: 1, at: DateTime(2026, 11, 2, 21, 5));
    expect(saved, h.value);
    final back = SongEntry.fromJson(h.value.single.toJson())!;
    expect(
      (back.title, back.station, back.stationNumber, back.at),
      ('Gidiyorum', 'A FM', 1, DateTime(2026, 11, 2, 21, 5)),
    );
  });

  test('radyo yayının bildirdiği başlığı çalan istasyonla geçmişe yazar', () async {
    final audio = FakeRadioAudio();
    final songs = SongHistory();
    final radio = RadioController(stations: ValueNotifier(const [_a, _b]), audio: () => audio, songs: songs);
    addTearDown(radio.dispose);
    await radio.play(_a);
    audio.icy = 'Sezen Aksu - Gidiyorum';
    await radio.play(_b);
    audio.icy = 'Tarkan - Kuzu Kuzu';
    expect(songs.value.map((e) => (e.title, e.station)), [
      ('Tarkan - Kuzu Kuzu', 'B Radyo'),
      ('Sezen Aksu - Gidiyorum', 'A FM'),
    ]);
  });
}
