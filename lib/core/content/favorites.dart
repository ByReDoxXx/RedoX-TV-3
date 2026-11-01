import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'favorite_folders.dart';
import 'live_channel.dart';

/// Bir profilin favorileri: TV kanalları ve radyo istasyonları (numaralar,
/// ekleme sırasıyla) ve iç içe klasörler (listeden aktarılan kayıtlar).
/// Cihazda saklanır.
class Favorites extends ChangeNotifier {
  Favorites({List<int> channels = const [], List<int> radios = const [], FavoriteFolder? folders, this.onSave})
    : _channels = List.of(channels),
      _radios = List.of(radios),
      folders = folders ?? FavoriteFolder('');

  final List<int> _channels;
  final List<int> _radios;
  final Future<void> Function(Favorites)? onSave;

  /// Klasör ağacının kökü (adı boş).
  final FavoriteFolder folders;

  static const _kChannels = 'favori_kanal';
  static const _kRadios = 'favori_radyo';
  static const _kFolders = 'favori_klasor';

  /// Cihazdaki favoriler: dönen işlev profilin favorilerini verir (aynı
  /// profil için hep aynı nesne).
  static Future<Favorites Function(String profileId)> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<int> read(String key) => [for (final s in prefs.getStringList(key) ?? const <String>[]) ?int.tryParse(s)];
    final cache = <String, Favorites>{};
    FavoriteFolder? tree(String key) {
      final text = prefs.getString(key);
      if (text == null) return null;
      try {
        return FavoriteFolder.fromJson((jsonDecode(text) as Map).cast());
      } on Object {
        return null;
      }
    }

    return (id) => cache[id] ??= Favorites(
      channels: read('${_kChannels}_$id'),
      radios: read('${_kRadios}_$id'),
      folders: tree('${_kFolders}_$id'),
      onSave: (f) async {
        await prefs.setStringList('${_kChannels}_$id', [for (final n in f._channels) '$n']);
        await prefs.setStringList('${_kRadios}_$id', [for (final n in f._radios) '$n']);
        await prefs.setString('${_kFolders}_$id', jsonEncode(f.folders.toJson()));
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

  // ---- Klasörler (yol: kökten klasör adları) --------------------------------

  /// Yoldaki klasör; yoksa null.
  FavoriteFolder? folderAt(List<String> path) {
    var f = folders;
    for (final name in path) {
      final next = f.child(name);
      if (next == null) return null;
      f = next;
    }
    return f;
  }

  /// [path] altında [name] klasörü (varsa olduğu gibi kalır).
  void addFolder(List<String> path, String name) {
    final parent = folderAt(path);
    final n = name.trim();
    if (parent == null || n.isEmpty) return;
    parent.ensure(n.replaceAll('/', '-'));
    _changed();
  }

  /// [path] klasörünü içindekilerle siler.
  void removeFolder(List<String> path) {
    if (path.isEmpty) return;
    folderAt(path.sublist(0, path.length - 1))?.folders.removeWhere((f) => f.name == path.last);
    _changed();
  }

  void removeItem(List<String> path, FavoriteItem item) {
    folderAt(path)?.items.remove(item);
    _changed();
  }

  /// Listeyi [path] klasörüne aktarır (FavoriteFolder.import). Döner: eklenen.
  int importChannels(List<String> path, List<LiveChannel> channels) {
    final f = folderAt(path);
    if (f == null) return 0;
    final added = f.import(channels);
    if (added > 0) _changed();
    return added;
  }

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
