import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/platform/full_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('çubuklar gizlenir, son ekran kapanınca geri gelir', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) calls.add('${call.method} ${call.arguments}');
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await FullScreen.enter();
    await FullScreen.enter();
    expect(calls, hasLength(1));
    expect(calls.single, contains('immersiveSticky'));

    await FullScreen.leave();
    expect(calls, hasLength(1), reason: 'alttaki oynatıcı ekranı hâlâ açık');

    await FullScreen.leave();
    expect(calls, hasLength(2));
    expect(calls.last, contains('SystemUiOverlay.bottom'));

    await FullScreen.leave();
    expect(calls, hasLength(2), reason: 'fazladan kapanış etkisiz');
  });
}
