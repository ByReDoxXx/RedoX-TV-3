import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/app.dart';
import 'package:redox_tv/core/brand/app_info.dart';
import 'package:redox_tv/core/content/app_settings.dart';
import 'package:redox_tv/core/content/content_locks.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/content/watch_history.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/platform/storage_access.dart';
import 'package:redox_tv/core/remote/remote_host.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/features/locks/lock_scope.dart';
import 'package:redox_tv/features/profiles/profile_picker_page.dart';
import 'package:redox_tv/features/settings/sections/about_settings.dart';
import 'package:redox_tv/features/settings/sections/data_settings.dart';
import 'package:redox_tv/features/settings/settings_page.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

Future<UserSources> _sources(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-ayar-');
  addTearDown(() => dir.delete(recursive: true));
  return UserSources.open(dir);
}))!;

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(FormFactor f, Widget page, {ContentLocks? locks, Key? boundary}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: LockScope(locks: locks ?? ContentLocks(), profiles: null, child: page),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('TV: solda bölümler, sağda seçili bölüm; ayar değişir; kumanda bölümü yalnız sunucuyla', (tester) async {
    await _size(tester, const Size(960, 540));
    final sources = await _sources(tester);
    final settings = AppSettings();
    final host = RemoteHost(name: 'Salon TV', onKey: (_) {}, tokens: const {'a', 'b'});
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        SettingsPage(
          sources: sources,
          clock: '20:45',
          profileName: 'Profil 1',
          profiles: ProfileStore(),
          settings: settings,
          remote: host,
        ),
        boundary: key,
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    for (final s in SettingsSection.values) {
      await tester.dragUntilVisible(find.text(s.label), find.byType(ListView).first, const Offset(0, -60));
      expect(find.text(s.label), findsWidgets, reason: s.label);
    }
    // Liste başa: Oynatıcı satırı görünür.
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await _settle(tester);
    await tester.ensureVisible(find.text('Oynatıcı').first);
    await tester.tap(find.text('Oynatıcı').first);
    await _settle(tester);
    await maybeSnapshot(tester, key, 'build/ayarlar/tv-oynatici.png', pixelRatio: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(QualityCap.fullHd.label));
    await tester.pump();
    expect(settings.quality, QualityCap.fullHd);

    await tester.ensureVisible(find.text('Telefon kumandası').first);
    await tester.tap(find.text('Telefon kumandası').first);
    await _settle(tester);
    expect(find.textContaining('Salon TV'), findsOneWidget);
    expect(find.textContaining('Eşleşmiş telefon: 2'), findsOneWidget);

    await tester.ensureVisible(find.text('Hakkında').first);
    await tester.tap(find.text('Hakkında').first);
    await _settle(tester);
    expect(find.text('RedoX TV $appVersion'), findsOneWidget);
    await maybeSnapshot(tester, key, 'build/ayarlar/tv-hakkinda.png', pixelRatio: 2);

    await tester.pumpWidget(
      _app(FormFactor.tv, SettingsPage(sources: sources, clock: '20:45', profileName: 'Profil 1')),
    );
    await _settle(tester);
    expect(find.text('Telefon kumandası'), findsNothing);
    expect(find.text('Ebeveyn denetimi'), findsNothing);
  });

  testWidgets('telefon: bölüm listesi taşmasız; bölüm açılır, Geri listeye döner', (tester) async {
    await _size(tester, const Size(412, 915));
    final sources = await _sources(tester);
    final settings = AppSettings();
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        FormFactor.phone,
        SettingsPage(
          sources: sources,
          clock: '20:45',
          profileName: 'Profil 1',
          profiles: ProfileStore(),
          settings: settings,
        ),
        boundary: key,
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await maybeSnapshot(tester, key, 'build/ayarlar/telefon-liste.png', pixelRatio: 2);
    await tester.tap(find.text('Açılış'));
    await _settle(tester);
    expect(find.textContaining('Kim izliyor?'), findsOneWidget);
    await tester.tap(find.text('Kapalı'));
    await tester.pump();
    expect(settings.askProfile, isFalse);
    await maybeSnapshot(tester, key, 'build/ayarlar/telefon-acilis.png', pixelRatio: 2);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Veriler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ebeveyn denetimi: kilitli içerik okunur adlarla listelenir', (tester) async {
    await _size(tester, const Size(960, 540));
    final sources = await _sources(tester);
    await tester.runAsync(
      () => sources.addText('Spor', '#EXTM3U\n#EXTINF:-1,A\nhttp://s/a.m3u8\n', origin: SourceOrigin.file),
    );
    final id = sources.items.single.id;
    final locks = ContentLocks({
      ContentLocks.channel(5),
      ContentLocks.folder(id, ['Maç']),
      ContentLocks.item('http://s/film.mp4'),
    });
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        SettingsPage(
          sources: sources,
          clock: '20:45',
          profileName: 'Profil 1',
          profiles: ProfileStore(),
          channelName: (n) => n == 5 ? 'TRT Belgesel' : null,
          initialSection: SettingsSection.parental,
        ),
        locks: locks,
      ),
    );
    await _settle(tester);
    expect(find.text('Kanal 5 · TRT Belgesel'), findsOneWidget);
    expect(find.text('Spor › Maç'), findsOneWidget);
    expect(find.text('Kayıt · film.mp4'), findsOneWidget);
    expect(find.text('Kilidi kaldır'), findsNWidgets(3));
  });

  testWidgets('Veriler: geçmiş temizlenir; yedek klasöre yazılır', (tester) async {
    await _size(tester, const Size(960, 540));
    StorageAccess.debugOverride = () async => true;
    addTearDown(() => StorageAccess.debugOverride = null);
    final sources = await _sources(tester);
    final out = (await tester.runAsync(() => Directory.systemTemp.createTemp('redox-yedek-')))!;
    addTearDown(() => out.delete(recursive: true));
    final history = WatchHistory(const [1, 2]);
    await tester.pumpWidget(
      _app(FormFactor.tv, DataSettings(sources: sources, history: history, backupFolder: () async => out)),
    );
    await _settle(tester);
    await tester.tap(find.text('Geçmişi temizle'));
    await _settle(tester);
    await tester.tap(find.text('Sil'));
    await _settle(tester);
    expect(history.value, isEmpty);
    await tester.tap(find.text('Yedek al'));
    await _settle(tester);
    final files = (await tester.runAsync(() => out.list().toList()))!;
    expect(files.single.path, endsWith('.json'));
  });

  testWidgets('Görünüm: yazı boyutu; Hakkında: cihaz ve hata raporu', (tester) async {
    await _size(tester, const Size(960, 540));
    StorageAccess.debugOverride = () async => true;
    addTearDown(() => StorageAccess.debugOverride = null);
    final sources = await _sources(tester);
    final settings = AppSettings();
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        SettingsPage(
          sources: sources,
          clock: '20:45',
          profileName: 'Profil 1',
          settings: settings,
          initialSection: SettingsSection.appearance,
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text(TextSize.large.label));
    await tester.pump();
    expect(settings.textSize, TextSize.large);

    final out = (await tester.runAsync(() => Directory.systemTemp.createTemp('redox-rapor-')))!;
    addTearDown(() => out.delete(recursive: true));
    await tester.pumpWidget(_app(FormFactor.tv, AboutSettings(sources: sources, reportFolder: () async => out)));
    await _settle(tester);
    expect(find.text('Cihaz'), findsOneWidget);
    await tester.tap(find.text('Rapor kaydet'));
    await _settle(tester);
    final files = (await tester.runAsync(() => out.list().toList()))!;
    expect(files.single.path, endsWith('.txt'));
  });

  testWidgets("kabukta Geri: ayar bölümünden listeye, dizi sayfasından Dizi'ye (Anasayfa'ya değil)", (tester) async {
    await _size(tester, const Size(412, 915));
    final sources = await _sources(tester);
    await tester.runAsync(
      () => sources.addText(
        'Dizilerim',
        '#EXTM3U\n#EXTINF:-1,Ezel S01E01\nhttp://o/1.mp4\n#EXTINF:-1,Ezel S01E02\nhttp://o/2.mp4\n',
        origin: SourceOrigin.file,
        kind: SourceKind.series,
      ),
    );
    Widget shell(AppSection initial) => MaterialApp(
      theme: RedoxTheme.dark(formFactor: FormFactor.phone),
      home: RootShell(key: ValueKey(initial), tv: TvContent.preview, initial: initial, sources: sources),
    );
    await tester.pumpWidget(shell(AppSection.settings));
    await _settle(tester);
    await tester.tap(find.text('Oynatıcı'));
    await _settle(tester);
    expect(find.text('Kalite sınırı'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Veriler'), findsOneWidget, reason: 'bölüm listesine döndü');
    expect(find.byType(SettingsPage), findsOneWidget, reason: "Anasayfa'ya gitmedi");
    // İkinci tur (Pixel'de ikinci Geri listeye dönmedi).
    for (final section in ['Görünüm', 'Hakkında', 'Açılış']) {
      await tester.tap(find.text(section));
      await _settle(tester);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('Veriler'), findsNothing, reason: '$section açık');
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Veriler'), findsOneWidget, reason: '$section: Geri listeye döndü');
    }

    await tester.pumpWidget(shell(AppSection.series));
    await _settle(tester);
    await tester.tap(find.text('Ezel'));
    await tester.pumpAndSettle();
    expect(find.text('Bölüm 2'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bölüm 2'), findsNothing, reason: 'dizi sayfası kapandı');
    expect(find.text('Ezel'), findsOneWidget, reason: "Dizi ızgarasına döndü, Anasayfa'ya değil");
  });

  testWidgets('OLED modu: arka plan ve alt çubuk saf siyah; kapalıyken gece laciverti', (tester) async {
    await _size(tester, const Size(412, 915));
    final previous = AppSettings.instance;
    final settings = AppSettings(askProfile: false);
    AppSettings.instance = settings;
    addTearDown(() => AppSettings.instance = previous);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RedoxApp(
          tv: ValueNotifier(TvContent.preview),
          profiles: ProfileStore(lastId: 'p1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    Color background() => Theme.of(tester.element(find.byType(RootShell))).scaffoldBackgroundColor;
    expect(background(), isNot(RedoxTheme.oledBlack));
    settings.oled = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(background(), RedoxTheme.oledBlack);
    final bar = tester.widget<Material>(
      find.descendant(of: find.byType(RedoxBottomBar), matching: find.byType(Material)).first,
    );
    expect(bar.color, RedoxTheme.oledBlack);
    await settleAssets(tester, rounds: 3);
    await maybeSnapshot(tester, key, 'build/ayarlar/oled-anasayfa.png', pixelRatio: 2);
  });

  testWidgets('Açılış: "Kim izliyor?" kapalıysa son profil doğrudan açılır', (tester) async {
    await _size(tester, const Size(960, 540));
    final previous = AppSettings.instance;
    AppSettings.instance = AppSettings(askProfile: false);
    addTearDown(() => AppSettings.instance = previous);
    await tester.pumpWidget(
      RedoxApp(
        tv: ValueNotifier(TvContent.preview),
        profiles: ProfileStore(lastId: 'p1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ProfilePickerPage), findsNothing);
    expect(find.byType(RootShell), findsOneWidget);
  });
}
