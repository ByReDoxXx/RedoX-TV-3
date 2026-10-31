import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'data_pack.dart';
import 'remote_file.dart';
import 'xmltv.dart';

/// Yayın akışı: şifreli paket (`epg.bin`, [DataPack]), ByReDoxXx/redox-epg
/// deposunda günde iki kez üretilir. İçinde XMLTV kaynakları öncelik
/// sırasıyla durur; uygulama birleştirir ([EpgGuide.mergedWith]: aynı saatte
/// iki kaynakta program varsa öndeki kalır, sonraki boşlukları ve eksik
/// kanalları doldurur):
/// 1. epgshare01 Türkiye dosyası: Türksat Kablo'dan, gönüllü servis; gece
///    yarısını geçen programlar tam. 204 kanalın 31'i.
/// 2. iptv-org/epg aracıyla TV+'tan (bir kanal Digiturk), yalnız listemizdeki
///    kanallar için. 48 kanal, 20'si yalnız burada (TRT 2, NOW, Halk TV…).
/// İkisi birlikte 31 Ekim 2026'da 51 kanal.
abstract final class EpgSource {
  static const url = 'https://raw.githubusercontent.com/ByReDoxXx/redox-epg/main/epg.bin';

  /// Paketi indirir ve açar. İnmez ya da açılmazsa [EpgGuide.empty]
  /// (uygulama akışsız çalışır).
  static Future<EpgGuide> load(DataPack pack, {String from = url}) async {
    try {
      final bytes = await fetchBytes(Uri.parse(from));
      // Çözme (2–3 MB XML) zayıf TV işlemcisinde arayüzü takılmasın diye ayrı
      // iş parçacığında.
      return await Isolate.run(() async => fromPack(await pack.open(bytes, kind: DataPack.epg)));
    } on Object {
      return EpgGuide.empty;
    }
  }

  /// `{"sources": [{"name", "xmltv": base64}]}` → birleşik akış. Okunamayan
  /// kaynak atlanır.
  static EpgGuide fromPack(Map<String, Object?> json) {
    var merged = EpgGuide.empty;
    for (final source in json['sources'] as List? ?? const []) {
      if (source case {'xmltv': final String data}) {
        try {
          merged = merged.mergedWith(EpgGuide.parse(decode(base64.decode(data))));
        } on Object {
          // Sıradaki kaynak.
        }
      }
    }
    return merged;
  }

  /// gzip ise açar (ilk iki bayt 1F 8B), UTF-8 çözer; baştaki BOM atılır
  /// (epgshare01 dosyası BOM'la başlıyor, XML çözücü kabul etmiyor).
  static String decode(List<int> bytes) {
    final raw = bytes.length > 1 && bytes[0] == 0x1f && bytes[1] == 0x8b ? gzip.decode(bytes) : bytes;
    final text = utf8.decode(raw, allowMalformed: true);
    return text.startsWith('﻿') ? text.substring(1) : text;
  }
}
