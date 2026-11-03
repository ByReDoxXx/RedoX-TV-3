import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/features/search/library_search.dart';

const _films = '''#EXTM3U
#EXTINF:-1 group-title="Aksiyon",|TR| Flaş (2023) [4K]
http://o/f1.mkv
#EXTINF:-1 group-title="Bilim Kurgu",Oppenheimer (2023)
http://o/f2.mkv
''';

const _series = '''#EXTM3U
#EXTINF:-1 group-title="Diziler",Çukur S01E01
http://o/c11.mkv
#EXTINF:-1 group-title="Diziler",Arrow S01E01
http://o/a11.mkv
''';

Future<UserSources> _sources() async {
  final dir = await Directory.systemTemp.createTemp('redox-arama-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  await s.addText('Filmlerim', _films, origin: SourceOrigin.file, kind: SourceKind.film);
  await s.addText('Dizilerim', _series, origin: SourceOrigin.file, kind: SourceKind.series);
  await s.addText('Canlı', '#EXTM3U\n#EXTINF:-1,Flaş TV\nhttp://o/c.m3u8\n', origin: SourceOrigin.file);
  return s;
}

void main() {
  test('Film ve Dizi kaynaklarında arar (Türkçe harf sadeleşir); canlı kanallar burada yok', () async {
    final search = await LibrarySearch.load(await _sources());
    expect(search.matchFilms('flas').map((f) => f.name), ['|TR| Flaş (2023) [4K]']);
    expect(search.matchFilms('OPPEN').map((f) => f.streams.single), ['http://o/f2.mkv']);
    expect(search.matchSeries('cukur').map((s) => s.name), ['Çukur']);
    expect(search.matchSeries('arrow').single.episodeCount, 1);
    expect(search.matchFilms('  '), isEmpty);
  });

  test('büyük listede adlar ayrı isolate’ta sadeleşir', () async {
    final dir = await Directory.systemTemp.createTemp('redox-arama-');
    addTearDown(() => dir.delete(recursive: true));
    final s = await UserSources.open(dir);
    final m3u = StringBuffer('#EXTM3U\n');
    for (var i = 0; i < LibrarySearch.isolateThreshold + 5; i++) {
      m3u.write('#EXTINF:-1 group-title="Film",Film Numara $i\nhttp://o/$i.mp4\n');
    }
    m3u.write('#EXTINF:-1 group-title="Film",Şahsiyet Özel\nhttp://o/s.mp4\n');
    await s.addText('Büyük', m3u.toString(), origin: SourceOrigin.file, kind: SourceKind.film);
    final search = await LibrarySearch.load(s);
    expect(search.matchFilms('sahsiyet ozel').single.name, 'Şahsiyet Özel');
    expect(search.matchFilms('film numara').length, 50, reason: 'en çok SearchPage.limit');
  });
}
