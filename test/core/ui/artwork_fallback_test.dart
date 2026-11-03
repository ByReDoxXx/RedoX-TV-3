import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/artwork_fallback.dart';

void main() {
  testWidgets('baş harfler: yıl, etiket ve işaretler atlanır ("Başlangıç (2010)" → "B", "B(" değil)', (tester) async {
    for (final (name, initials) in const [
      ('Başlangıç (2010)', 'B'),
      ('Mad Max (2015)', 'MM'),
      ('|TR| Dune', 'D'),
      ('Yüzüklerin Efendisi', 'YE'),
      ('ilk ışık', 'İI'),
      ('(2010)', '('),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: RedoxTheme.dark(formFactor: FormFactor.tv),
          home: SizedBox.square(dimension: 200, child: ArtworkFallback(name: name)),
        ),
      );
      expect(find.text(initials), findsOneWidget, reason: name);
    }
  });
}
