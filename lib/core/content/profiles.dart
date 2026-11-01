import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İzleyici profili. Çocuk profili yalnız "Çocuk" kategorisindeki kanalları
/// görür; çıkışı ebeveyn PIN'i ister.
@immutable
class Profile {
  const Profile({required this.id, required this.name, this.color = 0, this.kids = false});

  factory Profile.fromJson(Map<String, Object?> j) => Profile(
    id: j['id']! as String,
    name: j['name']! as String,
    color: (j['color'] as int?) ?? 0,
    kids: (j['kids'] as bool?) ?? false,
  );

  final String id;
  final String name;

  /// Avatar rengi (ProfileAvatar.colors dizini).
  final int color;
  final bool kids;

  /// Çocuk profilinde görünen tek kategori.
  static const kidsCategory = 'Çocuk';

  /// Avatar harfi: Türkçe büyük harf ("i" → "İ").
  String get initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final c = t.substring(0, 1);
    return switch (c) {
      'i' => 'İ',
      'ı' => 'I',
      _ => c.toUpperCase(),
    };
  }

  Profile copyWith({String? name, int? color}) =>
      Profile(id: id, name: name ?? this.name, color: color ?? this.color, kids: kids);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'color': color, 'kids': kids};

  @override
  bool operator ==(Object other) =>
      other is Profile && other.id == id && other.name == name && other.color == color && other.kids == kids;

  @override
  int get hashCode => Object.hash(id, name, color, kids);
}

/// Profiller, son kullanılan profil ve ebeveyn PIN'i (cihazda saklanır).
/// PIN düz değil, rastgele tuzla SHA-256 özeti olarak durur.
class ProfileStore extends ChangeNotifier {
  ProfileStore({List<Profile> profiles = defaults, this.lastId, this._pinSalt, this._pinHash, this._save})
    : _profiles = List.of(profiles);

  /// İlk açılış: bir yetişkin ve bir çocuk profili.
  static const defaults = [
    Profile(id: 'p1', name: 'Profil 1'),
    Profile(id: 'cocuk', name: 'Çocuk', color: 2, kids: true),
  ];

  static const maxProfiles = 6;
  static const pinLength = 4;

  static const _kProfiles = 'profiller';
  static const _kLast = 'son_profil';
  static const _kSalt = 'pin_tuz';
  static const _kHash = 'pin_ozet';

  /// Cihazdaki profilleri okur; yoksa varsayılanlar.
  static Future<ProfileStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    var profiles = defaults;
    final raw = prefs.getString(_kProfiles);
    if (raw != null) {
      try {
        final list = [for (final j in jsonDecode(raw) as List) Profile.fromJson(j as Map<String, Object?>)];
        if (list.isNotEmpty) profiles = list;
      } on Object {
        // Bozuk kayıt: varsayılanlar.
      }
    }
    return ProfileStore(
      profiles: profiles,
      lastId: prefs.getString(_kLast),
      pinSalt: prefs.getString(_kSalt),
      pinHash: prefs.getString(_kHash),
      save: (s) async {
        await prefs.setString(_kProfiles, jsonEncode([for (final p in s.profiles) p.toJson()]));
        if (s.lastId case final id?) await prefs.setString(_kLast, id);
        if (s._pinSalt case final salt?) {
          await prefs.setString(_kSalt, salt);
        } else {
          await prefs.remove(_kSalt);
        }
        if (s._pinHash case final hash?) {
          await prefs.setString(_kHash, hash);
        } else {
          await prefs.remove(_kHash);
        }
      },
    );
  }

  final List<Profile> _profiles;
  final Future<void> Function(ProfileStore)? _save;
  String? _pinSalt;
  String? _pinHash;

  /// En son seçilen profil (çocuksa açılışta yetişkin profili PIN ister).
  String? lastId;

  List<Profile> get profiles => List.unmodifiable(_profiles);

  Profile? byId(String? id) => _profiles.where((p) => p.id == id).firstOrNull;

  /// Son kullanılan profil çocuk profiliyse: başka profile geçmek PIN ister.
  bool get lockedToKids => byId(lastId)?.kids ?? false;

  bool get hasPin => _pinHash != null;

  bool get canAdd => _profiles.length < maxProfiles;

  void _changed() {
    notifyListeners();
    unawaited(_save?.call(this));
  }

  void select(Profile p) {
    lastId = p.id;
    _changed();
  }

  Profile add({required String name, required int color, bool kids = false}) {
    final p = Profile(id: 'p${DateTime.now().microsecondsSinceEpoch}', name: name.trim(), color: color, kids: kids);
    _profiles.add(p);
    _changed();
    return p;
  }

  void update(Profile p) {
    final i = _profiles.indexWhere((e) => e.id == p.id);
    if (i < 0) return;
    _profiles[i] = p;
    _changed();
  }

  /// Siler; en az bir yetişkin profili kalmalıdır.
  bool remove(Profile p) {
    if (!canRemove(p)) return false;
    _profiles.removeWhere((e) => e.id == p.id);
    if (lastId == p.id) lastId = null;
    _changed();
    return true;
  }

  bool canRemove(Profile p) => p.kids || _profiles.where((e) => !e.kids && e.id != p.id).isNotEmpty;

  Future<void> setPin(String pin) async {
    assert(pin.length == pinLength);
    final rnd = Random.secure();
    final salt = base64.encode([for (var i = 0; i < 16; i++) rnd.nextInt(256)]);
    _pinSalt = salt;
    _pinHash = await _hash(salt, pin);
    _changed();
  }

  /// PIN'i siler (Ayarlar › Ebeveyn PIN'i; önce mevcut PIN sorulur). Çocuk
  /// profiline sonraki girişte yenisi istenir.
  void clearPin() {
    _pinSalt = null;
    _pinHash = null;
    _changed();
  }

  Future<bool> checkPin(String pin) async {
    final salt = _pinSalt, hash = _pinHash;
    if (salt == null || hash == null) return false;
    return await _hash(salt, pin) == hash;
  }

  static Future<String> _hash(String salt, String pin) async =>
      base64.encode((await Sha256().hash(utf8.encode('$salt:$pin'))).bytes);
}
