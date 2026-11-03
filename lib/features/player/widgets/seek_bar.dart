import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_type.dart';

/// Film ve dizi bölümünde sarma çubuğu (kullanıcı isteği: "ileri geri
/// sarabileceğim bar"): geçen süre, çubuk, toplam süre. Sürüklerken konum
/// yazısı sürükleneni gösterir, bırakınca sarılır. [onSeek] null ise yalnız
/// gösterir (TV'de ◄► ile sarılırken).
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    this.onSeek,
    this.onDragging,
    this.remaining = false,
  });

  /// Sağda toplam süre yerine kalan süre ("−1:18:28").
  final bool remaining;

  final ValueListenable<Duration> position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;

  /// Sürükleme başladı/bitti (dokunma katmanı bu sürede kapanmasın).
  final ValueChanged<bool>? onDragging;

  /// "1:05:09" ya da "4:07".
  static String format(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int n) => '$n'.padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  /// Sürüklenen konum (0–1); sürüklenmiyorsa null.
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = widget.duration.inMilliseconds;
    final style = t.labelLarge!.copyWith(color: Colors.white, fontFeatures: RedoxType.tabular);
    return ValueListenableBuilder(
      valueListenable: widget.position,
      builder: (context, position, _) {
        final value = _drag ?? (total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0));
        final shown = Duration(milliseconds: (value * total).round());
        return Row(
          children: [
            Text(SeekBar.format(shown), style: style),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: RedoxRoles.primaryContainer,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: RedoxRoles.primaryContainer.withValues(alpha: 0.25),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: value,
                  semanticFormatterCallback: (v) => SeekBar.format(Duration(milliseconds: (v * total).round())),
                  onChangeStart: widget.onSeek == null
                      ? null
                      : (v) {
                          widget.onDragging?.call(true);
                          setState(() => _drag = v);
                        },
                  onChanged: widget.onSeek == null ? null : (v) => setState(() => _drag = v),
                  onChangeEnd: widget.onSeek == null
                      ? null
                      : (v) {
                          widget.onSeek!(Duration(milliseconds: (v * total).round()));
                          widget.onDragging?.call(false);
                          setState(() => _drag = null);
                        },
                ),
              ),
            ),
            Text(
              widget.remaining ? '−${SeekBar.format(widget.duration - shown)}' : SeekBar.format(widget.duration),
              style: style,
            ),
          ],
        );
      },
    );
  }
}
