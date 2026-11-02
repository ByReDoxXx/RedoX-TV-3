import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../content/app_settings.dart';

/// Akışları açılış öncesi sıralar (PlaybackSession).
typedef StreamRanker = Future<List<String>> Function(List<String> streams);

/// Bir akışın yoklama sonucu.
class StreamInfo {
  const StreamInfo(this.url, {this.latency, this.bitrate});

  final String url;

  /// Oynatma listesinin inme süresi; null: açılmadı.
  final Duration? latency;

  /// Bit/sn: ana listede en yüksek BANDWIDTH, tek kaliteli listede ilk
  /// parçanın boyutu / süresi; null: bilinmiyor.
  final int? bitrate;

  bool get ok => latency != null;
}

/// Kanalın akışlarını aynı anda yoklar ve "hızlı açılanlar içinde bit hızı
/// en yüksek olan önde" sırasıyla dizer (kullanıcı isteği). Sonuç kanal
/// başına [cacheFor] boyunca saklanır: kanallar arası gezerken her seferinde
/// yeniden yoklanmaz.
class StreamProbe {
  StreamProbe({
    this.timeout = const Duration(seconds: 2),
    this.cacheFor = const Duration(minutes: 30),
    this.probe,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Bu süreyi aşan akış "açılmadı" sayılır (sırada en sona kalır, yedek
  /// olarak). Parça boyutu sorgusu en çok 1 sn daha sürer: yoklama kanal
  /// açılışına en çok ~3 sn ekler (kanal başına bir kez, [cacheFor] boyunca).
  final Duration timeout;
  final Duration cacheFor;

  /// Tek akışın yoklaması; null ise HTTP (testlerde sahte).
  final Future<StreamInfo> Function(String url)? probe;
  final DateTime Function() _clock;
  final _cache = <String, (DateTime, List<String>)>{};

  /// Akışları sıralar; tek akışta yoklamaz.
  Future<List<String>> rank(List<String> streams) async {
    if (streams.length < 2) return streams;
    final key = streams.join('\n');
    final cached = _cache[key];
    if (cached != null && _clock().difference(cached.$1) < cacheFor) return cached.$2;
    final infos = await Future.wait([for (final s in streams) (probe ?? _http)(s)]);
    final ordered = order(infos, maxBitrate: capBitrate(AppSettings.instance.quality));
    _cache[key] = (_clock(), ordered);
    return ordered;
  }

  /// Kalite sınırının bit hızı karşılığı (yaklaşık; akışın çözünürlüğü
  /// yoklamada bilinmez): Full HD için 12, HD için 6 Mbit/sn. Üstündeki
  /// akışlar (çoğunlukla 4K) hızlı olsalar da sınırın altındakilerden sonra
  /// gelir, kendi aralarında düşükten yükseğe.
  static int? capBitrate(QualityCap cap) => switch (cap) {
    QualityCap.highest => null,
    QualityCap.fullHd => 12000000,
    QualityCap.hd => 6000000,
  };

  /// Sıra: önce "hızlı" akışlar (en hızlının iki katı ya da +0,7 sn içinde
  /// açılanlar) bit hızına göre (bilinmeyen en sonda, eşitlikte hızlı olan),
  /// sonra yavaş açılanlar hıza göre, en sonda açılmayanlar (liste sırasıyla:
  /// yoklamada açılmayan oynatıcıda açılabilir).
  static List<String> order(List<StreamInfo> infos, {int? maxBitrate}) {
    final ok = infos.where((i) => i.ok).toList()..sort((a, b) => a.latency!.compareTo(b.latency!));
    if (ok.isEmpty) return [for (final i in infos) i.url];
    final fastest = ok.first.latency!;
    final limit = fastest * 2 > fastest + const Duration(milliseconds: 700)
        ? fastest * 2
        : fastest + const Duration(milliseconds: 700);
    final fast = ok.where((i) => i.latency! <= limit).toList()
      ..sort((a, b) {
        if (maxBitrate != null) {
          final aOver = (a.bitrate ?? 0) > maxBitrate, bOver = (b.bitrate ?? 0) > maxBitrate;
          if (aOver != bOver) return aOver ? 1 : -1;
          // İkisi de sınırın üstünde: sınıra yakın (düşük) olan önde.
          if (aOver) return a.bitrate!.compareTo(b.bitrate!);
        }
        final byRate = (b.bitrate ?? -1).compareTo(a.bitrate ?? -1);
        return byRate != 0 ? byRate : a.latency!.compareTo(b.latency!);
      });
    final slow = ok.where((i) => i.latency! > limit);
    return [
      for (final i in fast) i.url,
      for (final i in slow) i.url,
      for (final i in infos)
        if (!i.ok) i.url,
    ];
  }

  /// Oynatma listesinden bit hızı ipucu: ana liste (EXT-X-STREAM-INF) ise en
  /// yüksek BANDWIDTH; tek kaliteli ise ilk parçanın adresi ve süresi.
  static ({int? bandwidth, Uri? segment, double? duration}) parsePlaylist(String text, Uri base) {
    int? bandwidth;
    Uri? segment;
    double? duration;
    double? pending;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        final b = int.tryParse(RegExp(r'BANDWIDTH=(\d+)').firstMatch(line)?[1] ?? '');
        if (b != null && b > (bandwidth ?? 0)) bandwidth = b;
      } else if (line.startsWith('#EXTINF:')) {
        pending = double.tryParse(RegExp(r'#EXTINF:([\d.]+)').firstMatch(line)?[1] ?? '');
      } else if (line.isNotEmpty && !line.startsWith('#') && pending != null && segment == null) {
        segment = base.resolve(line);
        duration = pending;
      }
    }
    return (bandwidth: bandwidth, segment: bandwidth == null ? segment : null, duration: duration);
  }

  /// HTTP yoklaması: listeyi indirir (süre ölçülür); tek kaliteli listede ilk
  /// parçanın boyutunu HEAD ile sorar (yanıt vermezse bit hızı bilinmez).
  Future<StreamInfo> _http(String url) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final watch = Stopwatch()..start();
    try {
      final uri = Uri.parse(url);
      final response = await (await client.getUrl(uri)).close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) return StreamInfo(url);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final latency = watch.elapsed;
      if (!body.trimLeft().startsWith('#EXTM3U')) return StreamInfo(url);
      // Göreli parça adresleri yönlendirmeden sonraki adrese göre çözülür.
      final location = response.redirects.isEmpty ? uri : uri.resolveUri(response.redirects.last.location);
      final p = parsePlaylist(body, location);
      var bitrate = p.bandwidth;
      if (bitrate == null && p.segment != null && (p.duration ?? 0) > 0) {
        try {
          final head = await (await client.headUrl(p.segment!)).close().timeout(const Duration(seconds: 1));
          await head.drain<void>();
          if (head.contentLength > 0) bitrate = (head.contentLength * 8 / p.duration!).round();
        } on Object {
          // Bit hızı bilinmez; hız yine sayılır.
        }
      }
      return StreamInfo(url, latency: latency, bitrate: bitrate);
    } on Object {
      return StreamInfo(url);
    } finally {
      client.close(force: true);
    }
  }
}
