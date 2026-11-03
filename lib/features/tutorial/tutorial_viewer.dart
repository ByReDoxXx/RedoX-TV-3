import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';
import '../../core/theme/m3e_motion.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/key_hint.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'tutorial_stories.dart';

/// İzlenen öğretici hikâyeler (halka soluk çizilir); cihazda saklanır.
class TutorialSeen extends ValueNotifier<Set<AppSection>> {
  TutorialSeen._() : super(const {}) {
    unawaited(_load());
  }

  static final instance = TutorialSeen._();
  static const _key = 'egitim_goruldu';

  Future<void> _load() async {
    try {
      final names = (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];
      value = {...value, for (final n in names) ?AppSection.values.asNameMap()[n]};
    } on Object {
      // Saklanamıyor (test): yalnız oturum boyunca.
    }
  }

  void mark(AppSection s) {
    if (value.contains(s)) return;
    value = {...value, s};
    unawaited(
      SharedPreferences.getInstance()
          .then((p) => p.setStringList(_key, [for (final x in value) x.name]))
          .catchError((Object _) => false),
    );
  }
}

/// Görüntülerin vurgu dikdörtgenleri (`assets/tutorial/<cihaz>/manifest.json`):
/// görüntü → öğe anahtarı → [sol, üst, sağ, alt] (0–1).
abstract final class TutorialManifest {
  static final _cache = <String, Future<Map<String, Map<String, Rect>>>>{};

  static Future<Map<String, Map<String, Rect>>> load(String folder, {AssetBundle? bundle}) =>
      _cache[folder] ??= () async {
        try {
          final raw = jsonDecode(await (bundle ?? rootBundle).loadString('assets/tutorial/$folder/manifest.json'));
          return {
            for (final MapEntry(key: shot, value: rects) in (raw as Map<String, Object?>).entries)
              shot: {
                for (final MapEntry(:key, :value) in (rects as Map<String, Object?>).entries)
                  if (value case [final num l, final num t, final num r, final num b])
                    key: Rect.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble()),
              },
          };
        } on Object {
          return <String, Map<String, Rect>>{};
        }
      }();
}

/// Öğretici hikâyeyi tam ekran açar: [start]'taki bölümden başlar, bitince
/// sıradaki bölüme geçer. "Bölüme git" [onGo] ile o bölümü açar.
Future<void> showTutorial(
  BuildContext context, {
  required List<TutorialStory> stories,
  int start = 0,
  ValueChanged<AppSection>? onGo,
}) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    pageBuilder: (_, _, _) => TutorialViewer(stories: stories, start: start, onGo: onGo),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ),
);

/// Öğretici hikâye görüntüleyici (kullanıcı isteği: "uygulamayı öğretici
/// hikâye şeklinde kurgula"): cihazın kendi ekran görüntüsünde vurgulanan
/// öğe (çevresi karartılır, halka nabız gibi atar), başlık ve açıklama.
/// Üstte sayfa çubukları; sayfa [slideDuration] sonra kendiliğinden geçer.
///
/// Kumanda: sol/sağ önceki/sonraki sayfa, OK sonraki, yukarı bölüme git,
/// Geri kapat.
/// Dokunmatik: solda dokunma önceki, sağda sonraki; düğmeler.
class TutorialViewer extends StatefulWidget {
  const TutorialViewer({super.key, required this.stories, this.start = 0, this.onGo, this.bundle});

  final List<TutorialStory> stories;
  final int start;
  final ValueChanged<AppSection>? onGo;

  /// Testlerde görüntü ve manifest kaynağı.
  final AssetBundle? bundle;

  static const slideDuration = Duration(seconds: 10);

  @override
  State<TutorialViewer> createState() => _TutorialViewerState();
}

class _TutorialViewerState extends State<TutorialViewer> with TickerProviderStateMixin {
  late int _story = widget.start.clamp(0, widget.stories.length - 1);
  int _slide = 0;
  late final _timer = AnimationController(vsync: this, duration: TutorialViewer.slideDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  final _focus = FocusNode(debugLabel: 'öğretici');

  TutorialStory get _current => widget.stories[_story];

  @override
  void initState() {
    super.initState();
    unawaited(_timer.forward());
  }

  @override
  void dispose() {
    _timer.dispose();
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _restart() {
    _timer
      ..reset()
      ..forward();
  }

  void _next() {
    if (_slide + 1 < _current.slides.length) {
      setState(() => _slide++);
    } else {
      TutorialSeen.instance.mark(_current.section);
      if (_story + 1 >= widget.stories.length) {
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _story++;
        _slide = 0;
      });
    }
    _restart();
  }

  void _previous() {
    if (_slide > 0) {
      setState(() => _slide--);
    } else if (_story > 0) {
      setState(() {
        _story--;
        _slide = widget.stories[_story].slides.length - 1;
      });
    }
    _restart();
  }

  void _go() {
    final section = _current.section;
    TutorialSeen.instance.mark(section);
    Navigator.of(context).pop();
    widget.onGo?.call(section);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.select || LogicalKeyboardKey.enter:
        _next();
      case LogicalKeyboardKey.arrowLeft:
        _previous();
      case LogicalKeyboardKey.arrowUp when widget.onGo != null && _current.section != AppSection.home:
        _go();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final f = Theme.of(context).extension<RedoxMetrics>()!.formFactor;
    final slide = _current.slides[_slide];
    final folder = TutorialStories.folder(f);
    final wide = f != FormFactor.phone;
    final shot = _Shot(
      key: ValueKey('$_story-$_slide'),
      folder: folder,
      slide: slide,
      pulse: _pulse,
      phone: f == FormFactor.phone,
      bundle: widget.bundle,
    );
    final text = _Caption(
      story: _current,
      slide: slide,
      formFactor: f,
      last: _slide == _current.slides.length - 1,
      onGo: widget.onGo == null || _current.section == AppSection.home ? null : _go,
    );
    final bars = _Bars(count: _current.slides.length, index: _slide, progress: _timer);
    return Scaffold(
      backgroundColor: RedoxSeeds.obsidian,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(wide ? 32 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: bars),
                    if (f != FormFactor.tv) ...[
                      const SizedBox(width: 12),
                      IconActionButton(icon: RedoxIcons.close, onPressed: () => Navigator.of(context).maybePop()),
                    ],
                  ],
                ),
                SizedBox(height: wide ? 20 : 12),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Dokunmatik: sol üçte bir önceki, gerisi sonraki.
                    onTapUp: (d) {
                      final w = context.size?.width ?? 1;
                      d.globalPosition.dx < w / 3 ? _previous() : _next();
                    },
                    child: AnimatedSwitcher(
                      duration: M3EMotion.medium2,
                      child: wide
                          ? Row(
                              key: ValueKey('$_story-$_slide'),
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 3, child: shot),
                                const SizedBox(width: 32),
                                Expanded(flex: 2, child: text),
                              ],
                            )
                          : Column(
                              key: ValueKey('$_story-$_slide'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: shot),
                                const SizedBox(height: 14),
                                text,
                              ],
                            ),
                    ),
                  ),
                ),
                if (f == FormFactor.tv) ...[const SizedBox(height: 12), _Hints(go: widget.onGo != null)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sayfa çubukları: geçmiş dolu, şimdiki dolarak, gelecek boş.
class _Bars extends StatelessWidget {
  const _Bars({required this.count, required this.index, required this.progress});

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, _) => Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: i < index ? 1 : (i == index ? progress.value : 0),
                minHeight: 4,
                backgroundColor: RedoxRoles.onSurface.withValues(alpha: 0.18),
                color: RedoxSeeds.gold,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Cihaz çerçevesinde ekran görüntüsü ve vurgu.
class _Shot extends StatelessWidget {
  const _Shot({
    super.key,
    required this.folder,
    required this.slide,
    required this.pulse,
    required this.phone,
    this.bundle,
  });

  final String folder;
  final TutorialSlide slide;
  final Animation<double> pulse;
  final bool phone;
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/tutorial/$folder/${slide.shot}.webp',
      bundle: bundle,
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => const ColoredBox(color: RedoxRoles.surfaceContainer),
    );
    // Görüntü oranı: TV 16:9, tablet 16:10, telefon 390:844.
    final ratio = switch (folder) {
      'tv' => 16 / 9,
      'tablet' => 16 / 10,
      _ => 390 / 844,
    };
    final radius = BorderRadius.circular(phone ? 26 : 14);
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: DecoratedBox(
          // Cihaz çerçevesi: koyu kenar ve altın çizgi.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(phone ? 32 : 18),
            color: const Color(0xFF05050E),
            border: Border.all(color: RedoxSeeds.gold.withValues(alpha: 0.35)),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: Padding(
            padding: EdgeInsets.all(phone ? 6 : 8),
            child: ClipRRect(
              borderRadius: radius,
              child: FutureBuilder(
                future: TutorialManifest.load(folder, bundle: bundle),
                builder: (context, snap) {
                  final rect = slide.highlight == null ? null : snap.data?[slide.shot]?[slide.highlight];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      if (rect != null)
                        AnimatedBuilder(
                          animation: pulse,
                          builder: (context, _) => CustomPaint(
                            painter: _Spotlight(rect: rect, t: pulse.value),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vurgu: dikdörtgen dışı karartılır, çevresinde nabız gibi atan halka.
class _Spotlight extends CustomPainter {
  const _Spotlight({required this.rect, required this.t});

  /// 0–1 oranlarıyla.
  final Rect rect;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    ).inflate(6);
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(12));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = RedoxSeeds.gold,
    );
    // Dışa yayılan halka.
    final grow = 4 + t * 14;
    canvas.drawRRect(
      hole.inflate(grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = RedoxSeeds.amber.withValues(alpha: (1 - t) * 0.8),
    );
  }

  @override
  bool shouldRepaint(_Spotlight old) => old.rect != rect || old.t != t;
}

/// Bölüm adı, sayfa başlığı, açıklama ve (son sayfada) "Bölüme git".
class _Caption extends StatelessWidget {
  const _Caption({required this.story, required this.slide, required this.formFactor, required this.last, this.onGo});

  final TutorialStory story;
  final TutorialSlide slide;
  final FormFactor formFactor;
  final bool last;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tv = formFactor == FormFactor.tv;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: RedoxSeeds.crimson.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(RedoxRadius.md),
              ),
              child: RedoxIcon(story.section.icon, color: RedoxRoles.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              story.section.label.toUpperCase(),
              style: t.labelLarge!.copyWith(color: RedoxSeeds.gold, letterSpacing: 2, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        SizedBox(height: tv ? 16 : 10),
        Text(
          slide.title,
          style: (tv ? t.headlineMedium : t.headlineSmall)!.copyWith(
            color: RedoxRoles.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide.text(formFactor),
          style: (tv ? t.titleMedium : t.bodyLarge)!.copyWith(color: RedoxRoles.onSurfaceVariant, height: 1.45),
        ),
        if (onGo != null && (last || !tv)) ...[
          SizedBox(height: tv ? 22 : 14),
          tv
              ? Row(
                  children: [
                    const _ArrowKey([RedoxIcons.expandLess]),
                    const SizedBox(width: 8),
                    Text(
                      '${story.section.label} bölümüne git',
                      style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface),
                    ),
                  ],
                )
              : GlassButton(label: '${story.section.label} bölümüne git', icon: story.section.icon, onPressed: onGo),
        ],
      ],
    );
  }
}

/// Ok tuşu kapakçığı: Sora'da ok karakterleri yok (kutu çiziliyordu), ikon.
class _ArrowKey extends StatelessWidget {
  const _ArrowKey(this.icons);

  final List<RedoxIcons> icons;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: RedoxRoles.onSurface.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(RedoxRadius.xs),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final i in icons) RedoxIcon(i, color: RedoxRoles.onSurface, size: 16)],
    ),
  );
}

/// TV tuş ipuçları.
class _Hints extends StatelessWidget {
  const _Hints({required this.go});

  final bool go;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget hint(Widget key, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key,
        const SizedBox(width: 6),
        Text(label, style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
      ],
    );
    return Wrap(
      spacing: 22,
      children: [
        hint(const _ArrowKey([RedoxIcons.chevronLeft, RedoxIcons.chevronRight]), 'Sayfa'),
        hint(const KeyHint('OK', color: RedoxRoles.onSurface), 'Sonraki'),
        if (go) hint(const _ArrowKey([RedoxIcons.expandLess]), 'Bölüme git'),
        hint(const KeyHint('Geri', color: RedoxRoles.onSurface), 'Kapat'),
      ],
    );
  }
}
