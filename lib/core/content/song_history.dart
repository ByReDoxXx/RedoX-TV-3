import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Radyoda çalan bir şarkı (yayının bildirdiği başlık).
@immutable
class SongEntry {
  const SongEntry({required this.title, required this.station, required this.stationNumber, required this.at});

  /// Yayının gönderdiği başlık, örn. "Sezen Aksu - Gidiyorum".
  final String title;
  final String station;
  final int stationNumber;
  final DateTime at;

  Map<String, Object> toJson() => {'t': title, 's': station, 'n': stationNumber, 'a': at.millisecondsSinceEpoch};

  static SongEntry? fromJson(Object? json) => switch (json) {
    {'t': final String t, 's': final String s, 'n': final int n, 'a': final int a} => SongEntry(
      title: t,
      station: s,
      stationNumber: n,
      at: DateTime.fromMillisecondsSinceEpoch(a),
    ),
    _ => null,
  };
}

/// Son dinlenen şarkılar (kullanıcı isteği: son 15), en yenisi önde. Cihazda
/// saklanır. Aynı şarkı art arda gelirse (yayın başlığı yeniden gönderir) bir
/// kez yazılır; başlık istasyon adıyla aynıysa şarkı sayılmaz.
class SongHistory extends ValueNotifier<List<SongEntry>> {
  SongHistory([super.value = const [], this._save]);

  static const limit = 15;
  static const _key = 'son_sarkilar';

  final Future<void> Function(List<SongEntry>)? _save;

  static Future<SongHistory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = [for (final s in prefs.getStringList(_key) ?? const <String>[]) ?_decode(s)];
    return SongHistory(saved, (list) => prefs.setStringList(_key, [for (final e in list) jsonEncode(e.toJson())]));
  }

  static SongEntry? _decode(String s) {
    try {
      return SongEntry.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }

  void record(String title, {required String station, required int stationNumber, DateTime? at}) {
    final t = title.trim();
    if (t.isEmpty || t.toLowerCase() == station.trim().toLowerCase()) return;
    final last = value.firstOrNull;
    if (last != null && last.title == t && last.stationNumber == stationNumber) return;
    final entry = SongEntry(title: t, station: station, stationNumber: stationNumber, at: at ?? DateTime.now());
    value = [entry, ...value].take(limit).toList();
    unawaited(_save?.call(value));
  }

  void clear() {
    value = const [];
    unawaited(_save?.call(value));
  }
}
