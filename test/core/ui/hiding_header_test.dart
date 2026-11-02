import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/ui/hiding_header.dart';

Widget _page({int items = 60}) => MaterialApp(
  home: Scaffold(
    body: HidingHeader(
      header: const SizedBox(height: 56, child: Text('Başlık')),
      child: ListView(children: [for (var i = 0; i < items; i++) SizedBox(height: 60, child: Text('Satır $i'))]),
    ),
  ),
);

double _headerHeight(WidgetTester tester) => tester.getSize(find.byType(ClipRect).first).height;

void main() {
  testWidgets('aşağı kaydırınca gizlenir, yukarı kaydırınca geri gelir; başta hep açık', (tester) async {
    await tester.pumpWidget(_page());
    expect(_headerHeight(tester), 56 + 12);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), 0, reason: 'aşağı kaydırınca gizli');

    await tester.drag(find.byType(ListView), const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), 56 + 12, reason: 'yarıdan fazla geri geldi: tamamen açılır');

    await tester.drag(find.byType(ListView), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), 56 + 12, reason: 'azıcık kaydırma: açık kalır');

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), 56 + 12, reason: 'liste başında açık');
    expect(find.byType(ShaderMask), findsNothing, reason: 'başta solma yok');
  });

  testWidgets('kaydırılmışken içeriğin üst kenarı solar', (tester) async {
    await tester.pumpWidget(_page());
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('kısa içerikte gizlenmez', (tester) async {
    await tester.pumpWidget(_page(items: 9));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_headerHeight(tester), 56 + 12);
  });
}
