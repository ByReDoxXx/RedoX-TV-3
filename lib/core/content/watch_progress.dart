import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channel_folder.dart';
import 'live_channel.dart';

/// Film ya da dizi bölümünün izlendiği yer.
@immutable
class ProgressEntry {
  const ProgressEntry({
    required this.url,
    required this.title,
    required this.series,
    required this.position,
    required this.duration,
    required this.at,
    this.poster,
  });

  factory ProgressEntry.fromJson(Map<String, Object?> j) => ProgressEntry(
    url: j['adres'] as String,
    title: j['ad'] as String,
    series: j['dizi'] == true,
    position: Duration(milliseconds: j['konum'] as int),
    duration: Duration(milliseconds: j['sure'] as int),
    at: DateTime.fromMillisecondsSinceEpoch(j['an'] as int),
    poster: j['afis'] as String?,
  );

  /// Yayın adresi (kimlik).
  final String url;

  /// Listedeki ad ("Adanalı S02E03" ya da film adı).
  final String title;

  /// Dizi bölümü mü (film değil).
  final bool series;
  final Duration position;
  final Duration duration;

  /// Son izlenme anı.
  final DateTime at;
  final String? poster;

  /// İzlenen oran (0–1).
  double get fraction =>
      duration.inMilliseconds == 0 ? 0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  /// Bitti sayılır (son %5 ya da son 2 dakika: jenerik).
  bool get finished => fraction >= 0.95 || duration - position < const Duration(minutes: 2);

  /// Dizi bölümünün adı çözümlenmiş hâli; çözülemezse null.
  ({String series, int season, int episode, String title})? get episode =>
      series ? ChannelFolder.parseEpisode(title) : null;

  /// Kalan süre: "1 sa 12 dk kaldı", "12 dk kaldı".
  String get remaining {
    final left = duration - position;
    final h = left.inHours, m = left.inMinutes % 60;
    return h > 0 ? '$h sa $m dk kaldı' : '${left.inMinutes.clamp(1, 59)} dk kaldı';
  }

  /// Oynatıcıda açmak için kanal.
  LiveChannel get channel => LiveChannel(name: title, number: 0, category: '', streams: [url], logoUrl: poster);

  Map<String, Object?> toJson() => {
    'adres': url,
    'ad': title,
    'dizi': series,
    'konum': position.inMilliseconds,
    'sure': duration.inMilliseconds,
    'an': at.millisecondsSinceEpoch,
    'afis': ?poster,
  };
}

/// Kaldığı yerden devam (kullanıcı isteği: "Film ve Diziler için kaldığım
/// yerden devam et"): film ve dizi bölümlerinin izlendiği yer, profil
/// başına cihazda. Oynatıcı ilerlemeyi yazar, açılışta okur; Anasayfa
/// "İzlemeye devam et" rafını buradan kurar. En çok [limit] kayıt.
class WatchProgress extends ChangeNotifier {
  WatchProgress([List<ProgressEntry> entries = const [], this._save]) {
    for (final e in entries) {
      _entries[e.url] = e;
    }
  }

  static const limit = 200;

  /// Bundan kısa izlenen yer saklanmaz (yanlışlıkla açılan).
  static const minimum = Duration(seconds: 30);

  static const _key = 'izleme_ilerleme';

  final _entries = <String, ProgressEntry>{};
  final Future<void> Function(List<ProgressEntry>)? _save;

  /// Cihazdaki ilerlemeler: dönen işlev profilinkini verir (aynı profil için
  /// hep aynı nesne).
  static Future<WatchProgress Function(String profileId)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = <String, WatchProgress>{};
    return (id) => cache[id] ??= () {
      final key = '${_key}_$id';
      final list = <ProgressEntry>[];
      for (final s in prefs.getStringList(key) ?? const <String>[]) {
        try {
          list.add(ProgressEntry.fromJson(jsonDecode(s) as Map<String, Object?>));
        } on Object {
          // Bozuk kayıt atlanır.
        }
      }
      return WatchProgress(list, (l) => prefs.setStringList(key, [for (final e in l) jsonEncode(e.toJson())]));
    }();
  }

  ProgressEntry? of(String url) => _entries[url];

  /// Devam edilecek yer: yarıda bırakılmışsa konum, değilse null.
  Duration? resumeAt(String url) {
    final e = _entries[url];
    if (e == null || e.finished || e.position < minimum) return null;
    return e.position;
  }

  /// İzlenen yeri yazar (oynatıcı birkaç saniyede bir ve kapanırken).
  void record(LiveChannel c, {required Duration position, required Duration duration, required bool series}) {
    final url = c.streams.firstOrNull;
    if (url == null || duration <= Duration.zero || position < minimum) return;
    _entries.remove(url);
    _entries[url] = ProgressEntry(
      url: url,
      title: c.name,
      series: series,
      position: position,
      duration: duration,
      at: DateTime.now(),
      poster: c.logoUrl,
    );
    while (_entries.length > limit) {
      _entries.remove(_entries.keys.first);
    }
    notifyListeners();
    unawaited(_save?.call(_entries.values.toList()));
  }

  void remove(String url) {
    if (_entries.remove(url) == null) return;
    notifyListeners();
    unawaited(_save?.call(_entries.values.toList()));
  }

  /// Yarıda bırakılan filmler ve bölümler, en son izlenen önde. Dizinin
  /// yalnız son izlenen bölümü (bitmiş olsa da: Anasayfa sıradakini önerir).
  List<ProgressEntry> get recent {
    final out = <ProgressEntry>[];
    final seenSeries = <String>{};
    for (final e in _entries.values.toList().reversed) {
      final ep = e.episode;
      if (ep != null) {
        if (!seenSeries.add(ep.series.toLowerCase())) continue;
        out.add(e);
      } else if (!e.finished) {
        out.add(e);
      }
    }
    return out;
  }
}
