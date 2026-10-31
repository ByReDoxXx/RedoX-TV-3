import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/epg_source.dart';
import 'package:redox_tv/core/content/xmltv.dart';

/// epgshare01 dosyasının biçimi (kısaltılmış): aynı kanalın iki kimliği,
/// +0300 dilimi, XML varlıkları, başlıksız program.
const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="none">
  <channel id="TRT.1.HD.tr"><display-name lang="tr">TRT 1 HD</display-name></channel>
  <channel id="TRT.1.tr"><display-name lang="tr">TRT 1</display-name></channel>
  <channel id="BENGÜ.TÜRK.tr"><display-name lang="tr">BENGÜ TÜRK</display-name></channel>
  <programme start="20261031210000 +0300" stop="20261031230000 +0300" channel="TRT.1.HD.tr">
    <title lang="tr">Dizi &amp; Film</title>
    <category lang="tr">Dizi</category>
  </programme>
  <programme start="20261031200000 +0300" stop="20261031210000 +0300" channel="TRT.1.tr">
    <title lang="tr">Ana Haber</title>
  </programme>
  <programme start="20261031210000 +0300" stop="20261031230000 +0300" channel="TRT.1.tr">
    <title lang="tr">Dizi &amp; Film</title>
  </programme>
  <programme start="20261031200000 +0300" stop="20261031210000 +0300" channel="BENGÜ.TÜRK.tr">
    <title lang="tr"></title>
  </programme>
</tv>''';

void main() {
  group('EpgGuide.key', () {
    test('ekler, boşluk, nokta ve Türkçe harfler eşlemeyi bozmaz', () {
      expect(EpgGuide.key('TRT 1 HD'), EpgGuide.key('TRT 1'));
      expect(EpgGuide.key('TRT.1.HD.tr'), EpgGuide.key('trt 1'));
      expect(EpgGuide.key('Bengütürk TV'), EpgGuide.key('BENGÜ TÜRK'));
      expect(EpgGuide.key('TRT Kurdî'), EpgGuide.key('TRT KURDİ'));
      expect(EpgGuide.key('Habertürk TV'), EpgGuide.key('HABERTÜRK HD'));
    });

    test('farklı kanallar ayrı kalır', () {
      expect(EpgGuide.key('TRT 1'), isNot(EpgGuide.key('TRT 2')));
      expect(EpgGuide.key('TV8'), isNot(EpgGuide.key('TV8.5')));
      expect(EpgGuide.key('A Haber'), isNot(EpgGuide.key('A Spor')));
    });
  });

  test('parseTime: dilim UTC\'ye çevrilir', () {
    expect(EpgGuide.parseTime('20261031210000 +0300')!.toUtc(), DateTime.utc(2026, 10, 31, 18));
    expect(EpgGuide.parseTime('20261031210000 -0130')!.toUtc(), DateTime.utc(2026, 10, 31, 22, 30));
    expect(EpgGuide.parseTime('20261031210000')!.toUtc(), DateTime.utc(2026, 10, 31, 21));
    expect(EpgGuide.parseTime('yarın'), isNull);
  });

  test('parse: kimlikler birleşir, programlar sıralı ve tekil, başlıksız atlanır', () {
    final g = EpgGuide.parse(_xml);
    final trt = g.of('TRT 1');
    expect(trt.map((p) => p.title), ['Ana Haber', 'Dizi & Film']);
    expect(trt.first.start.toUtc(), DateTime.utc(2026, 10, 31, 17));
    expect(trt.last.stop.toUtc(), DateTime.utc(2026, 10, 31, 20));
    expect(g.of('TRT 1 HD'), same(trt));
    expect(g.of('Bengütürk TV'), isEmpty);
    expect(g.of('Kanal yok'), isEmpty);
    expect(g.channelCount, 1);
  });

  test('isLiveAt: başlangıç dahil, bitiş hariç', () {
    final p = EpgGuide.parse(_xml).of('TRT 1').first;
    expect(p.isLiveAt(p.start), isTrue);
    expect(p.isLiveAt(p.stop), isFalse);
  });

  test('mergedWith: kanal ikisinde de varsa öndeki kazanır, ötekiler eklenir', () {
    DateTime t(int h) => DateTime(2026, 10, 31, h);
    final first = EpgGuide({
      EpgGuide.key('TRT 1'): [GuideEntry(title: 'Birinci', start: t(20), stop: t(21))],
    });
    final second = EpgGuide({
      EpgGuide.key('TRT 1'): [GuideEntry(title: 'İkinci', start: t(20), stop: t(21))],
      EpgGuide.key('Kanal D'): [GuideEntry(title: 'Dizi', start: t(20), stop: t(22))],
    });
    final m = first.mergedWith(second);
    expect(m.of('TRT 1').single.title, 'Birinci');
    expect(m.of('Kanal D').single.title, 'Dizi');
    expect(m.channelCount, 2);
    expect(EpgGuide.empty.mergedWith(second).channelCount, 2);
  });

  test('mergedWith: öndeki kaynağın boşluğunu çakışmayan programlar doldurur', () {
    DateTime t(int h) => DateTime(2026, 10, 31, h);
    // Öndeki kaynakta 20–24 arası boş (gece yarısını geçen program yok).
    final first = EpgGuide({
      EpgGuide.key('TRT 2'): [
        GuideEntry(title: 'Öğle', start: t(12), stop: t(20)),
        GuideEntry(title: 'Gece', start: DateTime(2026, 11, 1), stop: DateTime(2026, 11, 1, 2)),
      ],
    });
    final second = EpgGuide({
      EpgGuide.key('TRT 2'): [
        GuideEntry(title: 'Çakışan', start: t(19), stop: t(21)),
        GuideEntry(title: 'Akşam', start: t(21), stop: t(23)),
      ],
    });
    expect(first.mergedWith(second).of('TRT 2').map((e) => e.title), ['Öğle', 'Akşam', 'Gece']);
  });

  test('EpgSource.decode: gzip açılır, BOM atılır', () {
    final bytes = gzip.encode(utf8.encode('﻿$_xml'));
    final text = EpgSource.decode(bytes);
    expect(text.startsWith('<?xml'), isTrue);
    expect(EpgGuide.parse(text).of('TRT 1'), hasLength(2));
    expect(EpgSource.decode(utf8.encode('<tv/>')), '<tv/>');
  });
}
