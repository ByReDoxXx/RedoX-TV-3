import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV: filmin çizildiği, Flutter'ın arkasındaki ayrı yüzey (`VideoSurfaceHost.kt`).
/// Takılan oynatıcının yerine yenisi açılırken ikisi kısa süre bir arada olur; her
/// yüzeyin kendi kimliği var.
class NativeVideoSurface {
  NativeVideoSurface() : _id = _nextId++ {
    _live[_id] = this;
    _listen();
  }

  static const _channel = MethodChannel('redox/video-yuzey');
  static int _nextId = 1;
  static final _live = <int, NativeVideoSurface>{};
  static bool _listening = false;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      final surface = _live[args['id']];
      if (surface == null) return;
      switch (call.method) {
        case 'hazir':
          surface.wid.value = args['wid'] as int?;
        case 'gitti':
          surface.wid.value = null;
      }
    });
  }

  final int _id;

  /// mpv'ye verilecek yüzey başvurusu; yüzey yokken (arka planda) null.
  final wid = ValueNotifier<int?>(null);

  Rect? _placed;

  Future<void> open() => _channel.invokeMethod<void>('ac', {'id': _id});

  /// Yüzeyin ekrandaki yeri, fiziksel piksel.
  Future<void> place(Rect rect) async {
    if (rect == _placed) return;
    _placed = rect;
    await _channel.invokeMethod<void>('konum', {
      'id': _id,
      'sol': rect.left.round(),
      'ust': rect.top.round(),
      'genislik': rect.width.round(),
      'yukseklik': rect.height.round(),
    });
  }

  /// [keep]: takılı oynatıcı yüzeyi hâlâ tutuyor, başvurusu silinmesin.
  Future<void> close({required bool keep}) async {
    _live.remove(_id);
    wid.dispose();
    await _channel.invokeMethod<void>('kapat', {'id': _id, 'tut': keep});
  }
}

/// [video] boyutundaki görüntünün [box] içindeki yeri. SurfaceView dönüşümle
/// ölçeklenmez, gerçek yeri verilir. Görüntü boyutu bilinmiyorsa kutunun tamamı.
@visibleForTesting
Rect videoRect(Size box, Size? video, BoxFit fit) {
  if (video == null || video.isEmpty) return Offset.zero & box;
  final wide = box.width / video.width;
  final tall = box.height / video.height;
  final fitted = switch (fit) {
    BoxFit.fill => box,
    BoxFit.cover => video * max(wide, tall),
    BoxFit.contain => video * min(wide, tall),
    BoxFit.fitWidth => video * wide,
    BoxFit.fitHeight => video * tall,
    BoxFit.none => video,
    BoxFit.scaleDown => video * min(1.0, min(wide, tall)),
  };
  return Alignment.center.inscribe(fitted, Offset.zero & box);
}

/// Ekranı kaplayan görüntü alanı: kendisi saydam, yüzeyi arkada yerine koyar.
class NativeVideoView extends StatelessWidget {
  const NativeVideoView({
    super.key,
    required this.surface,
    required this.size,
    required this.fit,
    required this.subtitles,
    required this.subtitleStyle,
    required this.subtitlePadding,
  });

  final NativeVideoSurface surface;
  final Size? size;
  final BoxFit fit;
  final Stream<List<String>> subtitles;
  final TextStyle subtitleStyle;
  final EdgeInsets subtitlePadding;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = videoRect(constraints.biggest, size, fit);
        unawaited(
          surface.place(Rect.fromLTWH(rect.left * ratio, rect.top * ratio, rect.width * ratio, rect.height * ratio)),
        );
        // media_kit'in altyazı görünümüyle aynı ölçek; o görünüm kendi denetleyicisini ister.
        final scale = sqrt((constraints.maxWidth * constraints.maxHeight / (1920 * 1080)).clamp(0.0, 1.0));
        return Padding(
          padding: subtitlePadding,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StreamBuilder<List<String>>(
              stream: subtitles,
              builder: (context, snapshot) => Text(
                [
                  for (final line in snapshot.data ?? const <String>[])
                    if (line.trim().isNotEmpty) line.trim(),
                ].join('\n'),
                style: subtitleStyle,
                textAlign: TextAlign.center,
                textScaler: TextScaler.linear(scale),
              ),
            ),
          ),
        );
      },
    );
  }
}
