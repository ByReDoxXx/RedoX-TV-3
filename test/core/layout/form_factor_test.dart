import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';

void main() {
  test('Android flavor adı biçimi belirler', () {
    for (final p in TargetPlatform.values) {
      expect(FormFactor.resolve('tv', p), FormFactor.tv);
      expect(FormFactor.resolve('tablet', p), FormFactor.tablet);
      expect(FormFactor.resolve('phone', p), FormFactor.phone);
    }
  });

  test('flavor yoksa: masaüstü platformları masaüstü, diğerleri telefon', () {
    expect(FormFactor.resolve(null, TargetPlatform.windows), FormFactor.desktop);
    expect(FormFactor.resolve(null, TargetPlatform.linux), FormFactor.desktop);
    expect(FormFactor.resolve(null, TargetPlatform.macOS), FormFactor.desktop);
    expect(FormFactor.resolve(null, TargetPlatform.android), FormFactor.phone);
  });

  test("flavor adları Gradle productFlavors ile aynı", () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    // Yalnız productFlavors bloğu (signingConfigs'te de create("release") var).
    final block = gradle.substring(gradle.indexOf('productFlavors'));
    final flavors = RegExp(r'create\("(\w+)"\)').allMatches(block).map((m) => m.group(1)).toSet();
    expect(flavors, {'tv', 'tablet', 'phone'});
    for (final f in flavors) {
      expect(FormFactor.resolve(f, TargetPlatform.android).name, f);
    }
  });

  test('TV manifesti: leanback, dokunmatik gerekmez, TV başlatıcısı, afiş', () {
    final tv = File('android/app/src/tv/AndroidManifest.xml').readAsStringSync();
    expect(tv, contains('android.software.leanback'));
    expect(RegExp(r'android\.hardware\.touchscreen"\s+android:required="false"').hasMatch(tv), isTrue);
    expect(tv, contains('android.intent.category.LEANBACK_LAUNCHER'));
    expect(tv, contains('android:banner="@drawable/banner"'));
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(main, isNot(contains('LEANBACK_LAUNCHER')), reason: 'telefon ve tablet APK TV başlatıcısında görünmemeli');
  });
}
