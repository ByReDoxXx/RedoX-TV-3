import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bir profilin favorileri: TV kanalları ve radyo istasyonları (numaralar,
/// ekleme sırasıyla). Cihazda saklanır.
class Favorites extends ChangeNotifier {
  Favorites({List<int> channels = const [], List<int> radios = const [], this.onSave})
    : _channels = List.of(channels),
      _radios = List.of(radios);

  final List<int> _channels;
  final List<int> _radios;
  final Future<void> Function(Favorites)? onSave;

  static const _kChannels = 'favori_kanal';
  static const _kRadios = 'favori_radyo';

  /// Cihazdaki favoriler: dönen işlev profilin favorilerini verir (aynı
  /// profil için hep aynı nesne).
  static Future<Favorites Function(String profileId)> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<int> read(String key) => [for (final s in prefs.getStringList(key) ?? const <String>[]) ?int.tryParse(s)];
    final cache = <String, Favorites>{};
    return (id) => cache[id] ??= Favorites(
      channels: read('${_kChannels}_$id'),
      radios: read('${_kRadios}_$id'),
      onSave: (f) async {
        await prefs.setStringList('${_kChannels}_$id', [for (final n in f._channels) '$n']);
        await prefs.setStringList('${_kRadios}_$id', [for (final n in f._radios) '$n']);
      },
    );
  }

  List<int> get channels => List.unmodifiable(_channels);
  List<int> get radios => List.unmodifiable(_radios);

  bool hasChannel(int number) => _channels.contains(number);
  bool hasRadio(int number) => _radios.contains(number);

  void toggleChannel(int number) => _toggle(_channels, number);
  void toggleRadio(int number) => _toggle(_radios, number);

  /// Sıralama (Favoriler sayfası): [number]'ı [to] konumuna taşır.
  void moveChannel(int number, int to) => _move(_channels, number, to);
  void moveRadio(int number, int to) => _move(_radios, number, to);

  void _toggle(List<int> list, int number) {
    if (!list.remove(number)) list.add(number);
    _changed();
  }

  void _move(List<int> list, int number, int to) {
    if (!list.remove(number)) return;
    list.insert(to.clamp(0, list.length), number);
    _changed();
  }

  void _changed() {
    notifyListeners();
    unawaited(onSave?.call(this));
  }
}
