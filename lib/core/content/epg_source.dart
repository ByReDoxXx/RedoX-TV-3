import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'xmltv.dart';

/// Yayın akışı kaynağı: XMLTV dosyasını indirir ve çözer.
///
/// Kaynak epgshare01'in Türkiye dosyası: Türksat Kablo'nun yayın akışından
/// her gün üretiliyor, 3 gün, ~170 KB (gzip). 31 Ekim 2026'da gömülü 204
/// kanalın 30'unu kapsıyordu. Gönüllü bir servistir; kapanırsa ya da kanal
/// eklemek gerekirse [urls] listesine ikinci kaynak eklenir (ör. iptv-org/epg
/// ile üretilen dosya).
abstract final class EpgSource {
  static const urls = ['https://epgshare01.online/epgshare01/epg_ripper_TR1.xml.gz'];

  /// Kaynakları sırayla dener; ilk okunabileni döndürür. Hiçbiri olmazsa
  /// [EpgGuide.empty] (uygulama akışsız çalışır).
  static Future<EpgGuide> load({List<String> from = urls, Duration timeout = const Duration(seconds: 30)}) async {
    for (final url in from) {
      try {
        final bytes = await _download(Uri.parse(url)).timeout(timeout);
        // Çözme (2–3 MB XML) zayıf TV işlemcisinde arayüzü takılmasın diye ayrı
        // iş parçacığında.
        final guide = await Isolate.run(() => EpgGuide.parse(decode(bytes)));
        if (guide.channelCount > 0) return guide;
      } on Object {
        // Sıradaki kaynak.
      }
    }
    return EpgGuide.empty;
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
