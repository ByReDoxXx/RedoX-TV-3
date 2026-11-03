import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/local_videos.dart';
import 'package:redox_tv/core/content/series_catalog.dart';
import 'package:redox_tv/core/content/user_sources.dart';

Future<Directory> _dir(String prefix) async {
  final d = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() => d.delete(recursive: true));
  return d;
}

Future<void> _touch(Directory root, String rel) async {
  final f = File('${root.path}/$rel');
  await f.parent.create(recursive: true);
  await f.writeAsString('x');
}

void main() {
  test('Film: ad dosya adı, kategori bulunduğu klasör (kökte klasörün adı); akış dosyanın yolu', () {
    const root = '/storage/SSD/Filmler';
    final films = LocalVideos.build(root, [
      '$root/Başlangıç (2010).mkv',
      '$root/Aksiyon/Mad_Max (2015).mp4',
    ], SourceKind.film);
    expect(films.map((c) => (c.name, c.category)), [('Başlangıç (2010)', 'Filmler'), ('Mad Max (2015)', 'Aksiyon')]);
    expect(films.first.streams, ['$root/Başlangıç (2010).mkv']);
  });

  test('Dizi: SxxEyy adı kalır; numarasız bölüm sezon klasöründen ve dosya numarasından', () {
    const root = r'D:\Diziler';
    // Windows yolları (ters eğik çizgi).
    String win(String rel) => '$root\\${rel.replaceAll('/', '\\')}';
    final eps = LocalVideos.build(root, [
      win('Arrow/Arrow S01E02.mkv'),
      win('Arrow/Sezon 2/03 1080p.mkv'),
      win('Arrow/Season 3/Pilot.avi'),
      win('Arrow/Season 3/Devam.avi'),
    ], SourceKind.series);
    expect(eps.map((c) => (c.name, c.category)), [
      ('Arrow S01E02', 'Arrow'),
      ('Arrow S02E03', 'Arrow'),
      ('Arrow S03E01', 'Arrow'),
      ('Arrow S03E02', 'Arrow'),
    ]);
    final series = SeriesCatalog.build([('k', eps)]).single;
    expect(series.name, 'Arrow');
    expect(series.seasons, [1, 2, 3]);
  });

  test('naturalCompare: "Bölüm 2" "Bölüm 10"dan önce', () {
    expect((['Bölüm 10', 'Bölüm 2', 'Bölüm 1']..sort(LocalVideos.naturalCompare)), ['Bölüm 1', 'Bölüm 2', 'Bölüm 10']);
  });

  test('tarama: alt klasörler dahil yalnız videolar; gizli ve Android klasörü atlanır', () async {
    final root = await _dir('redox-ssd-');
    for (final rel in [
      'Aksiyon/Film 10.mkv',
      'Aksiyon/Film 2.MP4',
      'Belgesel/Doğa.mov',
      'Eski/Klip.flv',
      'kapak.jpg',
      'altyazi.srt',
      '.gizli/gizli.mkv',
      'Android/data/x.mp4',
    ]) {
      await _touch(root, rel);
    }
    final films = await LocalVideos.scan(root.path, SourceKind.film);
    expect(films.map((c) => c.name), ['Film 2', 'Film 10', 'Doğa', 'Klip']);
  });

  test('videosuz ya da olmayan klasör hata verir', () async {
    final empty = await _dir('redox-bos-');
    await expectLater(LocalVideos.scan(empty.path, SourceKind.film), throwsA(isA<SourceException>()));
    await expectLater(LocalVideos.scan('${empty.path}/yok', SourceKind.film), throwsA(isA<SourceException>()));
  });

  test(
    'Klasörden kaynak: eklenir (ad klasörün adı), yenileyince yeni dosyalar gelir, yeniden açılınca durur',
    () async {
      final disk = await _dir('redox-ssd-');
      final media = Directory('${disk.path}/Filmlerim');
      await _touch(media, 'Başlangıç (2010).mkv');
      final store = await _dir('redox-kaynak-');
      final sources = await UserSources.open(store);
      final s = await sources.addFolder('', media.path);
      expect(
        (s.name, s.kind, s.origin, s.count, s.refreshable),
        ('Filmlerim', SourceKind.film, SourceOrigin.folder, 1, true),
      );

      await _touch(media, 'Yeni/Dune (2021).mp4');
      final updated = await sources.refresh(s);
      expect(updated.count, 2);

      final again = await UserSources.open(store);
      final films = await again.channels(again.of(SourceKind.film).single);
      expect(films.map((c) => (c.name, c.category)), [('Başlangıç (2010)', 'Filmlerim'), ('Dune (2021)', 'Yeni')]);
      expect(films.last.streams.single, endsWith('Dune (2021).mp4'));
    },
  );

  test('tek video seçilir: ad uzantısız dosya adı, kategori bulunduğu klasör', () async {
    final disk = await _dir('redox-ssd-');
    await _touch(disk, 'Filmler/Oppenheimer(2023).mkv');
    await _touch(disk, 'Filmler/Başka.mkv');
    final sources = await UserSources.open(await _dir('redox-kaynak-'));
    final s = await sources.addFolder('', '${disk.path}/Filmler/Oppenheimer(2023).mkv');
    expect((s.name, s.count), ('Oppenheimer(2023)', 1));
    final film = (await sources.channels(s)).single;
    expect((film.name, film.category), ('Oppenheimer(2023)', 'Filmler'));
    expect((await sources.refresh(s)).count, 1, reason: 'yenileyince yine yalnız o video');
  });
}
