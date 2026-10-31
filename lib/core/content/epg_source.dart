import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'xmltv.dart';

/// Yayın akışı kaynakları: XMLTV dosyalarını indirir, çözer ve birleştirir.
abstract final class EpgSource {
  /// Öncelik sırasıyla (aynı saatte iki kaynakta program varsa öndeki kalır,
  /// sonraki boşlukları ve eksik kanalları doldurur, [EpgGuide.mergedWith]):
  /// 1. epgshare01 Türkiye dosyası: Türksat Kablo'dan, gönüllü servis;
  ///    gece yarısını geçen programlar tam. 204 kanalın 31'i.
  /// 2. Kendi dosyamız (ByReDoxXx/redox-epg, herkese açık): iptv-org/epg
  ///    aracıyla günde iki kez TV+'tan (bir kanal Digiturk), yalnız
  ///    listemizdeki kanallar için. 49 kanal, 21'i yalnız burada (TRT 2, NOW,
  ///    Halk TV…).
  /// İkisi birlikte 31 Ekim 2026'da 52 kanal.
  static const urls = [
    'https://epgshare01.online/epgshare01/epg_ripper_TR1.xml.gz',
    'https://raw.githubusercontent.com/ByReDoxXx/redox-epg/main/guide.xml.gz',
  ];

  /// Bütün kaynakları aynı anda indirir; açılanları birleştirir. Hiçbiri
  /// açılmazsa [EpgGuide.empty] (uygulama akışsız çalışır).
  static Future<EpgGuide> load({List<String> from = urls, Duration timeout = const Duration(seconds: 30)}) async {
    final guides = await Future.wait([for (final url in from) _loadOne(url, timeout)]);
    return guides.fold<EpgGuide>(EpgGuide.empty, (merged, g) => merged.mergedWith(g));
  }

  static Future<EpgGuide> _loadOne(String url, Duration timeout) async {
    try {
      final bytes = await _download(Uri.parse(url)).timeout(timeout);
      // Çözme (2–3 MB XML) zayıf TV işlemcisinde arayüzü takılmasın diye ayrı
      // iş parçacığında.
      return await Isolate.run(() => EpgGuide.parse(decode(bytes)));
    } on Object {
      return EpgGuide.empty;
    }
  }

  /// gzip ise açar (ilk iki bayt 1F 8B), UTF-8 çözer; baştaki BOM atılır
  /// (epgshare01 dosyası BOM'la başlıyor, XML çözücü kabul etmiyor).
  static String decode(List<int> bytes) {
    final raw = bytes.length > 1 && bytes[0] == 0x1f && bytes[1] == 0x8b ? gzip.decode(bytes) : bytes;
    final text = utf8.decode(raw, allowMalformed: true);
    return text.startsWith('﻿') ? text.substring(1) : text;
  }

  static Future<List<int>> _download(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}', uri: uri);
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }
}
