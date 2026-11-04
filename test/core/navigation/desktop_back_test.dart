import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/desktop_back_button.dart';

import '../../support/render.dart';

void main() {
  Future<void> open(WidgetTester tester, FormFactor f) async {
    await loadSora(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: f),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: DesktopBackButton()))),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('masaüstünde düğme görünür ve sayfadan çıkar', (tester) async {
    await open(tester, FormFactor.desktop);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.text('aç'), findsOneWidget);
  });

  testWidgets('diğer cihazlarda yer kaplamaz', (tester) async {
    for (final f in [FormFactor.tv, FormFactor.tablet, FormFactor.phone]) {
      await open(tester, f);
      expect(find.byTooltip('Geri'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
