import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorite_folders.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/m3u_parser.dart';

void main() {
  test('aktarım: grup ve ad yolları iç içe klasör; grupsuz kayıt klasöre girer; tekrar eklenmez', () {
    final list = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 group-title="Dizi İsmi/1.Sezon",Bölüm01
http://ornek/d/1/1.mp4
#EXTINF:-1 group-title="Dizi İsmi/1.Sezon",Bölüm02
http://ornek/d/1/2.mp4
#EXTINF:-1 group-title="Dizi İsmi/2.Sezon",Bölüm01
http://ornek/d/2/1.mp4
#EXTINF:-1,Başka Dizi/1.Sezon/Bölüm01
http://ornek/b/1/1.mp4
#EXTINF:-1,Tek Film
http://ornek/film.mp4
''');
    final root = FavoriteFolder('');
    expect(root.import(list), 5);
    expect(root.import(list), 0, reason: 'aynı ad ve adres');

    final s1 = root.child('Dizi İsmi')!.child('1.Sezon')!;
    expect([for (final i in s1.items) i.name], ['Bölüm01', 'Bölüm02']);
    expect(root.child('Dizi İsmi')!.child('2.Sezon')!.items.single.url, 'http://ornek/d/2/1.mp4');
    expect(root.child('Başka Dizi')!.child('1.Sezon')!.items.single.name, 'Bölüm01');
    expect(root.items.single.name, 'Tek Film', reason: 'grupsuz ("Diğer") klasör açmaz');
    expect(root.total, 5);

    // Oynatıcı listesi: klasörün kayıtları sırayla.
    expect(
      [for (final c in s1.channels) (c.number, c.streams.single)],
      [(1, 'http://ornek/d/1/1.mp4'), (2, 'http://ornek/d/1/2.mp4')],
    );
  });

  test('JSON gidiş-dönüş ağacı korur', () {
    final root = FavoriteFolder('')
      ..import(const [
        LiveChannel(name: 'Bölüm01', number: 1, category: 'Dizi/1.Sezon', streams: ['a'], logoUrl: 'l'),
      ]);
    final back = FavoriteFolder.fromJson((jsonDecode(jsonEncode(root.toJson())) as Map).cast());
    final item = back.child('Dizi')!.child('1.Sezon')!.items.single;
    expect((item.name, item.url, item.logo), ('Bölüm01', 'a', 'l'));
  });

  test('Favorites: klasör ekle, yoldan aktar, sil; her değişiklik kaydedilir', () {
    var saves = 0;
    final fav = Favorites(onSave: (_) async => saves++);
    fav.addFolder(const [], 'Diziler');
    fav.addFolder(const [], 'Diziler');
    expect(fav.folders.folders, hasLength(1));
    expect(
      fav.importChannels(
        const ['Diziler'],
        const [
          LiveChannel(name: 'Bölüm01', number: 1, category: 'Dizi/1.Sezon', streams: ['a']),
        ],
      ),
      1,
    );
    expect(fav.folderAt(const ['Diziler', 'Dizi', '1.Sezon'])!.items.single.name, 'Bölüm01');
    fav.removeItem(const [
      'Diziler',
      'Dizi',
      '1.Sezon',
    ], fav.folderAt(const ['Diziler', 'Dizi', '1.Sezon'])!.items.first);
    expect(fav.folders.total, 0);
    fav.removeFolder(const ['Diziler']);
    expect(fav.folders.isEmpty, isTrue);
    expect(saves, 5);
  });
}
