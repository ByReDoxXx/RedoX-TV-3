import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/ui/decoded_size.dart';
import 'package:redox_tv/features/library/widgets/tmdb_poster.dart';

void main() {
  Future<ResizeImage> poster(WidgetTester tester, double width, {double ratio = 1}) async {
    tester.view.physicalSize = const Size(4000, 4000);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: width * 1.5,
            child: const TmdbPoster(name: 'Film', url: 'http://a.test/afis.jpg'),
          ),
        ),
      ),
    );
    return tester.widget<Image>(find.byType(Image)).image as ResizeImage;
  }

  testWidgets('afiş ekrandaki genişliğinde açılır', (tester) async {
    expect((await poster(tester, 200)).width, 200);
    expect((await poster(tester, 200, ratio: 2)).width, 400);
  });

  testWidgets('çok geniş yerleşimde sınırı aşmaz', (tester) async {
    expect((await poster(tester, 3000)).width, maxDecodedSize);
  });
}
