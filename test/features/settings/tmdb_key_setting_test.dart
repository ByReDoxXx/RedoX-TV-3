import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/backup.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/platform/system_text_input.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/settings/widgets/tmdb_key_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _token = 'uzun-okuma-belirteci';
const _short = '0123456789abcdef0123456789abcdef';

Widget _app(FormFactor f, Future<TmdbKeyCheck> Function(String) check) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: f),
  home: Scaffold(
    body: SingleChildScrollView(child: TmdbKeySetting(check: check)),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _size(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tmdb.current.value = null;
  });

  test('anahtar: girilmeden kapalı; saklanır, yeniden yüklenir, kaldırılır', () async {
    expect(Tmdb.shared, isNull);
    await Tmdb.setKey(_token);
    expect(Tmdb.shared?.token, _token);
    Tmdb.current.value = null;
    await Tmdb.loadKey();
    expect(Tmdb.shared?.token, _token);
    await Tmdb.setKey(null);
    expect(Tmdb.shared, isNull);
    await Tmdb.loadKey();
    expect(Tmdb.shared, isNull);
  });

  test('denetim: türüne göre gönderilir; 401 ret, başka hata ulaşılamadı', () async {
    late Uri uri;
    late Map<String, String> headers;
    Future<List<int>> ok(Uri u, Map<String, String> h) async {
      uri = u;
      headers = h;
      return utf8.encode('{"success":true}');
    }

    expect(await Tmdb.checkKey(_token, fetch: ok), TmdbKeyCheck.valid);
    expect(uri.path, '/3/authentication');
    expect(headers['Authorization'], 'Bearer $_token');
    expect(uri.queryParameters, isNot(contains('api_key')));

    expect(await Tmdb.checkKey(_short, fetch: ok), TmdbKeyCheck.valid);
    expect(uri.queryParameters['api_key'], _short);
    expect(headers, isNot(contains('Authorization')));

    expect(
      await Tmdb.checkKey(_token, fetch: (_, _) async => throw const HttpException('HTTP 401')),
      TmdbKeyCheck.rejected,
    );
    expect(
      await Tmdb.checkKey(_token, fetch: (_, _) async => throw const HttpException('HTTP 503')),
      TmdbKeyCheck.unreachable,
    );
    expect(
      await Tmdb.checkKey(_token, fetch: (_, _) async => throw const SocketException('ağ yok')),
      TmdbKeyCheck.unreachable,
    );
  });

  test('yedek: anahtar yazılmaz; geri yüklemede cihazdaki kalır, dosyadaki alınmaz', () async {
    final dir = await Directory.systemTemp.createTemp('redox-tmdb-');
    addTearDown(() => dir.delete(recursive: true));
    final sources = await UserSources.open(dir);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ayar_yazi', 'normal');
    await Tmdb.setKey(_token);

    final text = await Backup.create(sources);
    expect(text, isNot(contains(_token)));
    expect(text, isNot(contains(Tmdb.keyPref)));

    final foreign = jsonDecode(text) as Map<String, Object?>;
    (foreign['ayarlar']! as Map<String, Object?>)[Tmdb.keyPref] = 'dosyadaki';
    await Backup.restore(jsonEncode(foreign), sources);
    expect(prefs.getString(Tmdb.keyPref), _token);
    expect(prefs.getString('ayar_yazi'), 'normal');
  });

  testWidgets('TV: sistem kutusu gizli türde açılır; geçerli anahtar saklanır, kaldırılır', (tester) async {
    await _size(tester);
    TextKind? kind;
    SystemTextInput.debugOverride = (_, _, k) async {
      kind = k;
      return ' $_token ';
    };
    addTearDown(() => SystemTextInput.debugOverride = null);
    await tester.pumpWidget(_app(FormFactor.tv, (_) async => TmdbKeyCheck.valid));
    expect(find.text('TMDB anahtarı: girilmedi'), findsOneWidget);

    await tester.tap(find.text('Anahtarı gir'));
    await _settle(tester);
    expect(kind, TextKind.secret);
    expect(Tmdb.shared?.token, _token, reason: 'boşluklar atılır');
    expect(find.text('TMDB anahtarı: girildi'), findsOneWidget);
    expect(find.textContaining(_token), findsNothing, reason: 'anahtar ekranda görünmez');

    await tester.tap(find.text('Kaldır'));
    await _settle(tester);
    await tester.tap(find.text('Kaldır').last);
    await _settle(tester);
    expect(Tmdb.shared, isNull);
    expect(find.text('TMDB anahtarı: girilmedi'), findsOneWidget);
  });

  testWidgets('masaüstü: kutuya yazılır; reddedilen saklanmaz, uyarı çıkar', (tester) async {
    await _size(tester);
    await tester.pumpWidget(_app(FormFactor.desktop, (_) async => TmdbKeyCheck.rejected));
    await tester.tap(find.text('Anahtarı gir'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), _token);
    await tester.tap(find.text('Kaydet'));
    await _settle(tester);
    expect(Tmdb.shared, isNull);
    expect((await SharedPreferences.getInstance()).getString(Tmdb.keyPref), isNull);
    expect(find.text('TMDB bu anahtarı kabul etmedi; kaydedilmedi.'), findsOneWidget);
  });

  testWidgets('ulaşılamayınca anahtar saklanır; vazgeçilirse denenmez', (tester) async {
    await _size(tester);
    var checks = 0;
    await tester.pumpWidget(
      _app(FormFactor.desktop, (_) async {
        checks++;
        return TmdbKeyCheck.unreachable;
      }),
    );
    await tester.tap(find.text('Anahtarı gir'));
    await _settle(tester);
    await tester.tap(find.text('Vazgeç'));
    await _settle(tester);
    expect(checks, 0);

    await tester.tap(find.text('Anahtarı gir'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), _token);
    await tester.tap(find.text('Kaydet'));
    await _settle(tester);
    expect(Tmdb.shared?.token, _token);
  });
}
