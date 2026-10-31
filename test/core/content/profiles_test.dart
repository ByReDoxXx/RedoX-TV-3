import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('baş harf Türkçe büyük harftir', () {
    expect(const Profile(id: 'a', name: 'irem').initial, 'İ');
    expect(const Profile(id: 'a', name: 'ışık').initial, 'I');
    expect(const Profile(id: 'a', name: ' çağrı').initial, 'Ç');
    expect(const Profile(id: 'a', name: '').initial, '?');
  });

  test('ilk açılışta bir yetişkin ve bir çocuk profili', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await ProfileStore.load();
    expect(s.profiles, ProfileStore.defaults);
    expect(s.profiles.where((p) => p.kids), hasLength(1));
    expect(s.hasPin, isFalse);
    expect(s.lockedToKids, isFalse);
  });

  test('PIN düz saklanmaz; doğru PIN geçer, yanlışı geçmez', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await ProfileStore.load();
    await s.setPin('2468');
    expect(await s.checkPin('2468'), isTrue);
    expect(await s.checkPin('2469'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getKeys().map((k) => '${prefs.get(k)}').join();
    expect(stored, isNot(contains('2468')));
  });

  test('profiller, son profil ve PIN cihazda saklanır', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await ProfileStore.load();
    final p = s.add(name: 'Deniz', color: 4);
    s.select(ProfileStore.defaults.last);
    await s.setPin('1357');
    await pumpEventQueue();
    final again = await ProfileStore.load();
    expect(again.profiles.map((e) => e.name), ['Profil 1', 'Çocuk', 'Deniz']);
    expect(again.byId(p.id)?.color, 4);
    expect(again.lockedToKids, isTrue, reason: 'son profil çocuk profili');
    expect(await again.checkPin('1357'), isTrue);
  });

  test('son yetişkin profil silinemez; çocuk profili silinir', () {
    final s = ProfileStore();
    final adult = s.profiles.first, kids = s.profiles.last;
    expect(s.canRemove(adult), isFalse);
    expect(s.remove(adult), isFalse);
    expect(s.remove(kids), isTrue);
    expect(s.profiles, [adult]);
  });

  test('en çok altı profil', () {
    final s = ProfileStore();
    while (s.canAdd) {
      s.add(name: 'P', color: 0);
    }
    expect(s.profiles, hasLength(ProfileStore.maxProfiles));
  });
}
