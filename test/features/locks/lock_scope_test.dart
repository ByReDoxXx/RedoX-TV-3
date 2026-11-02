import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/content_locks.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/locks/lock_scope.dart';

import '../../support/render.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Kumandanın rakam tuşlarıyla PIN girer (PIN kontrolü gerçek zaman ister).
Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)));
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await _settle(tester);
}

void main() {
  group('ContentLocks', () {
    test('kilit, oturumluk açma ve kaydetme', () {
      Set<String>? saved;
      final l = ContentLocks(const {}, (s) async => saved = Set.of(s));
      final k = ContentLocks.channel(6);
      expect(l.blocks(k), isFalse);
      l.toggle(k);
      expect((l.isLocked(k), l.blocks(k)), (true, true));
      expect(saved, {k});
      l.unlock(k);
      expect((l.isLocked(k), l.blocks(k)), (true, false));
      l.toggle(k);
      expect(l.isLocked(k), isFalse);
      expect(saved, isEmpty);
    });

    test('klasör kilidi alt klasörleri de kapsar; kaynak kilidi her şeyi', () {
      final l = ContentLocks()..toggle(ContentLocks.folder('s1', const ['Diziler']));
      expect(l.folderLock('s1', const ['Diziler', '1.Sezon']), ContentLocks.folder('s1', const ['Diziler']));
      expect(l.folderLock('s1', const ['Filmler']), isNull);
      expect(l.folderLock('s2', const ['Diziler']), isNull);
      l.toggle(ContentLocks.folder('s1', const []));
      expect(l.folderLock('s1', const ['Filmler']), ContentLocks.folder('s1', const []));
    });
  });

  group('LockScope', () {
    Future<(LockScope, BuildContext)> pump(WidgetTester tester, ContentLocks locks, ProfileStore profiles) async {
      await loadSora(tester);
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: RedoxTheme.dark(formFactor: FormFactor.tv),
          home: LockScope(
            locks: locks,
            profiles: profiles,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  ctx = context;
                  return Center(child: LockButton(lockKey: ContentLocks.channel(6)));
                },
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      return (LockScope.maybeOf(ctx)!, ctx);
    }

    testWidgets('kilitli kanal doğru PIN ile açılır, oturum boyunca yeniden sormaz; yanlış PIN açmaz', (tester) async {
      final profiles = ProfileStore();
      await tester.runAsync(() => profiles.setPin('1234'));
      final locks = ContentLocks()..toggle(ContentLocks.channel(6));
      final (scope, ctx) = await pump(tester, locks, profiles);

      var result = scope.pass(ctx, ContentLocks.channel(6));
      await _settle(tester);
      expect(find.text("Ebeveyn PIN'i"), findsOneWidget);
      await _typePin(tester, '9999');
      expect(find.text("Ebeveyn PIN'i"), findsOneWidget, reason: 'yanlış PIN: pencere açık kalır');
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(await result, isFalse);

      result = scope.pass(ctx, ContentLocks.channel(6));
      await _settle(tester);
      await _typePin(tester, '1234');
      expect(await result, isTrue);
      expect(await scope.pass(ctx, ContentLocks.channel(6)), isTrue, reason: 'oturum boyunca açık');
    });

    testWidgets('kilit düğmesi PIN yoksa önce belirletir, sonra kilitler', (tester) async {
      final profiles = ProfileStore();
      final locks = ContentLocks();
      await pump(tester, locks, profiles);
      await tester.tap(find.bySemanticsLabel('Kilitle'));
      await _settle(tester);
      await _typePin(tester, '4321');
      await _typePin(tester, '4321');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _settle(tester);
      expect(profiles.hasPin, isTrue);
      expect(locks.isLocked(ContentLocks.channel(6)), isTrue);
      expect(find.bySemanticsLabel('Kilidi kaldır'), findsOneWidget);
    });
  });
}
