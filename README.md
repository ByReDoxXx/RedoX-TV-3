# RedoX TV 3.0

Flutter IPTV uygulaması: Android TV, Android tablet, Android telefon, Windows ve Linux.

- Tasarım kaynağı: [`design/DESIGN.md`](design/DESIGN.md)
- Tasarım kararları: [`design/DESIGN-KARARLAR.md`](design/DESIGN-KARARLAR.md)

## Derleme

Android'de televizyon, tablet ve telefon için ayrı APK'lar vardır. Flavor her zaman verilmelidir:

```bash
flutter build apk --release --flavor tv
flutter build apk --release --flavor tablet
flutter build apk --release --flavor phone
```

Çıktılar `build/app/outputs/flutter-apk/app-<flavor>-release.apk` olur. Geliştirirken de flavor verilir, örneğin `flutter run --flavor tv`.

Masaüstü derlemelerinde flavor yoktur:

```bash
flutter build windows --release
flutter build linux --release
```

Uygulamanın biçimi (TV, tablet, telefon, masaüstü) derlemeden gelir: `FormFactor.current` (`lib/core/layout/form_factor.dart`).

## Test

```bash
flutter analyze
flutter test
REDOX_SNAPSHOT=1 flutter test
```

Son komut, ekran görüntülerini `build/` altına yazar.
