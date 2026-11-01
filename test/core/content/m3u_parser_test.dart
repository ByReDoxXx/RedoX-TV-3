import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/m3u_parser.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

void main() {
  test('öznitelikler, aynı tvg-id akışları birleşir, numaraya göre sıralanır', () {
    const text = '''
#EXTM3U
#EXTINF:-1 tvg-id="b" tvg-chno="7" tvg-logo="https://ornek/b.png" group-title="Haber",B Haber
https://b/1.m3u8
#EXTINF:-1 tvg-id="a" tvg-chno="3" group-title="Ulusal",A TV
https://a/1.m3u8
# yorum satırı adres değildir
#EXTINF:-1 tvg-id="b" tvg-chno="7" group-title="Haber",B Haber
https://b/2.m3u8
#EXTINF:-1 group-title="Yerel, Ege",Numarasız, Kanal
https://c/1.m3u8
''';
    final channels = M3uParser.parse(text);
    expect([for (final c in channels) c.name], ['A TV', 'B Haber', 'Numarasız, Kanal']);
    final b = channels[1];
    expect(b.number, 7);
    expect(b.category, 'Haber');
    expect(b.logoUrl, 'https://ornek/b.png');
    expect(b.streams, ['https://b/1.m3u8', 'https://b/2.m3u8']);
    expect(b.programTitle, isNull, reason: 'M3U yayın akışı taşımaz');
    // Numarasız kanal sona, en büyük numaradan sonra; tırnak içindeki virgül
    // adı bölmez.
    expect(channels.last.number, 8);
    expect(channels.last.category, 'Yerel, Ege');
  });

  test('gömülü Türkçe liste: şifresiz, numaralar benzersiz ve artan, her kanalın akışı var', () {
    final tv = TvContent.fromM3u(File('assets/channels/tr.m3u').readAsStringSync());
    final c = tv.channels;
    // Yalnız TKGS kanalları (tools/kanal/turksat_sifresiz.txt).
    expect(c.length, greaterThan(100));
    // Ana kanallar önde (Türksat frekans listesi sırası; tools/kanal).
    expect(c.first.name, 'TRT 1');
    expect(c.first.number, 1);
    expect(c.firstWhere((x) => x.name == 'ATV').number, 7);
    expect(c.firstWhere((x) => x.name == 'Kanal D').number, 9);
    final numbers = [for (final x in c) x.number];
    expect(numbers.toSet().length, numbers.length);
    expect(numbers, orderedEquals([...numbers]..sort()));
    expect(c.every((x) => x.streams.isNotEmpty), isTrue);
    expect(c.any((x) => RegExp(r'bein|disney|baby tv|\bfx\b', caseSensitive: false).hasMatch(x.name)), isFalse);
    // Çipler sabit sırada başlar.
    expect(tv.categories.take(3), ['Ulusal', 'Haber', 'Spor']);
  });
}
