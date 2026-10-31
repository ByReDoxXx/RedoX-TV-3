import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/brand/brand_assets.dart';

import '../support/render.dart';

// Platform logo varyasyonlarının ölçüleri. Kaynaklar (developer.android.com):
// uyarlanabilir katman 108 dp, güvenli alan 66 dp; eski simge 48 dp;
// TV afişi xhdpi 320 x 180 px.

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

/// PNG IHDR: genişlik 16., yükseklik 20. bayttan başlar (big-endian).
(int, int) _pngSize(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  expect(b.getUint32(0), 0x89504E47, reason: '$path PNG değil');
  return (b.getUint32(16), b.getUint32(20));
}

void main() {
  group('Android', () {
    test('manifest: uygulama adı ortak, TV afişi yalnız TV APK\'sında', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:label="RedoX TV"'));
      final tv = File('android/app/src/tv/AndroidManifest.xml').readAsStringSync();
      expect(tv, contains('android:banner="@drawable/banner"'));
    });

    test('TV afişi xhdpi 320 x 180 px', () {
      expect(_pngSize('$_res/drawable-xhdpi/banner.png'), (320, 180));
    });

    test('her yoğunlukta simge ölçüleri: 48 dp ve 108 dp katmanlar', () {
      for (final MapEntry(key: name, value: d) in _densities.entries) {
        final legacy = (48 * d).round();
        final layer = (108 * d).round();
        expect(_pngSize('$_res/mipmap-$name/ic_launcher.png'), (legacy, legacy), reason: name);
        expect(_pngSize('$_res/mipmap-$name/ic_launcher_foreground.png'), (layer, layer), reason: name);
        expect(_pngSize('$_res/mipmap-$name/ic_launcher_monochrome.png'), (layer, layer), reason: name);
      }
    });

    test('uyarlanabilir simge katmanları ve renkler tanımlı', () {
      final xml = File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(xml, contains('<background android:drawable="@color/ic_launcher_background"'));
      expect(xml, contains('<foreground android:drawable="@mipmap/ic_launcher_foreground"'));
      expect(xml, contains('<monochrome android:drawable="@mipmap/ic_launcher_monochrome"'));
      final colors = File('$_res/values/colors.xml').readAsStringSync();
      expect(colors, contains('name="ic_launcher_background"'));
      expect(colors, contains('<color name="redox_obsidian">#0B0B20</color>'));
    });

    testWidgets('işaret 66 dp güvenli dairenin içinde', (tester) async {
      await tester.runAsync(() async {
        for (final file in ['ic_launcher_foreground.png', 'ic_launcher_monochrome.png']) {
          final bytes = File('$_res/mipmap-xxxhdpi/$file').readAsBytesSync();
          final frame = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
          final image = frame.image;
          final rgba = (await image.toByteData())!;
          final c = image.width / 2;
          var maxR = 0.0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (rgba.getUint8((y * image.width + x) * 4 + 3) > 64) {
                maxR = math.max(maxR, math.sqrt(math.pow(x + 0.5 - c, 2) + math.pow(y + 0.5 - c, 2)));
              }
            }
          }
          // xxxhdpi: 1 dp = 4 px; yarıçap 33 dp = 132 px (+1 px yeniden örnekleme payı).
          expect(maxR, lessThanOrEqualTo(33 * 4 + 1), reason: file);
          image.dispose();
        }
      });
    });

    test('açılış ve pencere zemini obsidyen (beyaz parlama yok)', () {
      for (final dir in ['values', 'values-night']) {
        final styles = File('$_res/$dir/styles.xml').readAsStringSync();
        expect('@color/redox_obsidian'.allMatches(styles).length, 2, reason: dir);
      }
    });
  });

  test('Windows ICO: 16-256 px arası 10 boyut', () {
    final b = ByteData.sublistView(File('windows/runner/resources/app_icon.ico').readAsBytesSync());
    expect(b.getUint16(2, Endian.little), 1, reason: 'ICO türü');
    final count = b.getUint16(4, Endian.little);
    final sizes = [
      for (var i = 0; i < count; i++)
        b.getUint8(6 + i * 16) == 0 ? 256 : b.getUint8(6 + i * 16),
    ]..sort();
    expect(sizes, [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]);
  });

  testWidgets('tam logo: kaynaktaki beyaz köşeler saydam', (tester) async {
    const magenta = Color(0xFFFF00FF);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: magenta,
              child: SvgPicture.asset(BrandAssets.logo, width: 200, height: 200),
            ),
          ),
        ),
      ),
    );
    await settleAssets(tester, rounds: 4);
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final rgba = (await image.toByteData())!;
      Color at(int x, int y) {
        final i = (y * image.width + x) * 4;
        return Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2));
      }

      // Dört köşe zemini gösterir; ortası (boğa) zemini göstermez.
      for (final (x, y) in [(2, 2), (197, 2), (2, 197), (197, 197)]) {
        expect(at(x, y), magenta, reason: 'köşe ($x, $y)');
      }
      expect(at(100, 100), isNot(magenta));
      image.dispose();
    });
  });

  test('işaret SVG: kare viewBox, yuvarlak köşeli kesme, yazı yolları yok', () {
    final svg = File(BrandAssets.mark).readAsStringSync();
    final vb = RegExp(r'viewBox="([\d.\-]+) ([\d.\-]+) ([\d.]+) ([\d.]+)"').firstMatch(svg)!;
    expect(vb.group(3), vb.group(4));
    expect(svg, contains('<clipPath id="tile"><rect'));
    final full = '<path'.allMatches(File(BrandAssets.logo).readAsStringSync()).length;
    expect('<path'.allMatches(svg).length, lessThan(full));
  });
}
