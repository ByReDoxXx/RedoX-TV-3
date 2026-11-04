import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/library/widgets/rating_line.dart';

const _info = TmdbInfo(id: 1, title: 'Film', year: 2021, rating: 7.3);

Widget _app(Future<double?>? imdb) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: FormFactor.tv),
  home: Scaffold(
    body: RatingLine(info: _info, extra: const ['Komedi'], imdb: imdb, style: const TextStyle(fontSize: 16)),
  ),
);

String _line(WidgetTester tester) => tester.widget<RichText>(find.byType(RichText).first).text.toPlainText();

void main() {
  testWidgets('anahtar yoksa yalnız TMDB; IMDb puanı gelince satıra eklenir', (tester) async {
    await tester.pumpWidget(_app(null));
    expect(_line(tester), contains('7.3 TMDB'));
    expect(_line(tester), isNot(contains('IMDb')));

    final imdb = Completer<double?>();
    await tester.pumpWidget(_app(imdb.future));
    expect(_line(tester), contains('7.3 TMDB'), reason: 'puan beklenirken satır durur');
    expect(_line(tester), isNot(contains('IMDb')));

    imdb.complete(8.8);
    await tester.pump();
    expect(_line(tester), contains('8.8 IMDb'));
    expect(_line(tester), contains('Komedi'));
  });

  testWidgets('IMDb puanı yoksa satırda yer almaz', (tester) async {
    await tester.pumpWidget(_app(Future.value()));
    await tester.pump();
    expect(_line(tester), isNot(contains('IMDb')));
  });
}
