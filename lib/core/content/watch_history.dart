import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Son izlenen kanallar: kanal numaraları, en yenisi önde. Cihazda saklanır
/// (uygulama kapanınca kaybolmaz). Kanal oynatıcıda görüntü verince kaydedilir.
class WatchHistory extends ValueNotifier<List<int>> {
  WatchHistory([super.value = const [], this._save]);

  /// Saklanan en çok kanal.
  static const limit = 12;

  static const _key = 'izlenen_kanallar';

  final Future<void> Function(List<int>)? _save;

  /// Cihazdaki geçmişler: her profilin ayrı listesi. Dönen işlev profilin
  /// geçmişini verir (aynı profil için hep aynı nesne). Profiller gelmeden
  /// önceki tek liste ilk profile ('p1') geçer.
  static Future<WatchHistory Function(String profileId)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = <String, WatchHistory>{};
    return (id) => cache[id] ??= () {
      final key = '${_key}_$id';
      final raw = prefs.getStringList(key) ?? (id == 'p1' ? prefs.getStringList(_key) : null);
      final saved = [for (final s in raw ?? const <String>[]) ?int.tryParse(s)];
      return WatchHistory(saved, (list) => prefs.setStringList(key, [for (final n in list) '$n']));
    }();
  }

  /// Kanalı başa alır (listede varsa yeri değişir).
  void record(int number) {
    if (value.isNotEmpty && value.first == number) return;
    value = [number, ...value.where((n) => n != number)].take(limit).toList();
    unawaited(_save?.call(value));
  }
}
