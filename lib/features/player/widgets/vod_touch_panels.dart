import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/content/tmdb.dart';
import '../../../core/content/watch_progress.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/redox_icon.dart';
import '../../library/widgets/tmdb_poster.dart';
import 'touch_controls.dart';
import 'vod_title.dart';
import 'vod_tv.dart';

// Film ve dizi oynatıcısının dokunmatik panelleri (telefon, tablet).

bool _isPhone(BuildContext context) => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;

/// Panel: telefonda alttan, tablette sağdan; dışına dokunmak kapatır.
class TouchSheet extends StatelessWidget {
  const TouchSheet({super.key, required this.title, required this.onClose, required this.child});

  /// Tablette panelin genişliği.
  static const sideWidth = 380.0;

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final phone = _isPhone(context);
    final panel = Material(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.96),
      borderRadius: phone
          ? const BorderRadius.vertical(top: Radius.circular(RedoxRadius.lg))
          : const BorderRadius.horizontal(left: Radius.circular(RedoxRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: !phone,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: phone ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium!
                          .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GlassCircle(icon: RedoxIcons.close, label: 'Kapat', size: 36, onPressed: onClose),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
        ),
        if (phone)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
              child: panel,
            ),
          )
        else
          Positioned(top: 0, right: 0, bottom: 0, width: sideWidth, child: panel),
      ],
    );
  }
}

/// Paneldeki seçim sütunu (Ses, Altyazı, Hız).
class ChoiceColumn {
  const ChoiceColumn({required this.title, required this.choices, required this.selected, required this.onSelect});

  final String title;

  /// Kimlik ve görünen ad.
  final List<(String, String)> choices;
  final String selected;
  final ValueChanged<String> onSelect;
}

/// Yan yana seçim sütunları; her seçim tek dokunuşla uygulanır.
class ChoicePanel extends StatelessWidget {
  const ChoicePanel({super.key, required this.columns});

  final List<ChoiceColumn> columns;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, c) in columns.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (columns.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                      child: Text(c.title, style: t.labelLarge!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                    ),
                  for (final (id, label) in c.choices)
                    _ChoiceRow(label: label, checked: id == c.selected, onTap: () => c.onSelect(id)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = checked ? RedoxRoles.tertiary : RedoxRoles.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
                ),
              ),
              if (checked) RedoxIcon(RedoxIcons.check, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bölüm listesi: telefonda yatay şerit, tablette iki sütun. Açılışta oynayan görünür.
class EpisodePanel extends StatefulWidget {
  const EpisodePanel({super.key, required this.episodes, required this.current, required this.onSelect, this.progress});

  final List<LiveChannel> episodes;
  final int current;
  final ValueChanged<int> onSelect;
  final WatchProgress? progress;

  /// Karonun metinle yüksekliği.
  static const tileHeight = 142.0;

  @override
  State<EpisodePanel> createState() => _EpisodePanelState();
}

class _EpisodePanelState extends State<EpisodePanel> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = _isPhone(context);
    const gap = 14.0;
    final columns = phone ? 1 : 2;
    final extent = phone ? EpisodeStrip.tileWidth : EpisodePanel.tileHeight;
    _scroll ??= ScrollController(initialScrollOffset: (widget.current ~/ columns) * (extent + gap));
    final grid = GridView.builder(
      controller: _scroll,
      scrollDirection: phone ? Axis.horizontal : Axis.vertical,
      itemCount: widget.episodes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisExtent: extent,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
      ),
      // Karonun yazısına dokunmak da açar (kumandada yalnız görsel odaklanır).
      itemBuilder: (context, i) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(i),
        child: EpisodeTile(
          episode: widget.episodes[i],
          entry: widget.progress?.of(widget.episodes[i].streams.firstOrNull ?? ''),
          playing: i == widget.current,
          onPressed: () => widget.onSelect(i),
        ),
      ),
    );
    return phone ? SizedBox(height: EpisodePanel.tileHeight, child: grid) : grid;
  }
}

/// Bölüm biterken: geri sayım, hemen oynat ya da vazgeç.
class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.label,
    required this.seconds,
    required this.onPlay,
    required this.onCancel,
  });

  final String label;
  final int seconds;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: const Color(0xE6000000),
      borderRadius: BorderRadius.circular(RedoxRadius.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$seconds sn sonra', style: t.bodySmall!.copyWith(color: Colors.white70)),
                Text(
                  label,
                  style: t.titleSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(width: 16),
            FilledButton(
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: RedoxRoles.primaryContainer,
                foregroundColor: Colors.white,
              ),
              child: const Text('Şimdi oynat'),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Duraklatınca solda afiş, puan ve özet (TMDB); başlık üst çubuktadır. Dar ekranda
/// çıkmaz: ortadaki düğmelerle çakışır.
class VodPauseInfo extends StatelessWidget {
  const VodPauseInfo({super.key, required this.channel, required this.series, this.tmdb});

  /// Bu genişliğin altında gösterilmez.
  static const minScreenWidth = 700.0;
  static const posterWidth = 84.0;

  final LiveChannel channel;
  final bool series;
  final Tmdb? tmdb;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < minScreenWidth) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final title = vodTitle(channel, series: series);
    return FutureBuilder(
      future: tmdb?.find(series ? title.title : channel.name, series: series) ?? Future<TmdbInfo?>.value(),
      builder: (context, snap) {
        final info = snap.data;
        final poster = channel.logoUrl ?? info?.poster;
        final overview = info?.overview ?? '';
        if (poster == null && overview.isEmpty) return const SizedBox.shrink();
        return IgnorePointer(
          child: Container(
            width: math.min(width * 0.31, 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xB3000000),
              borderRadius: BorderRadius.circular(RedoxRadius.lg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poster != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RedoxRadius.md),
                    child: SizedBox(
                      width: posterWidth,
                      height: posterWidth * 3 / 2,
                      child: TmdbPoster(name: title.title, url: poster),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (info?.rating case final rating?)
                        Text(
                          '${rating.toStringAsFixed(1)} TMDB',
                          style: t.labelMedium!.copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w700),
                        ),
                      if (overview.isNotEmpty)
                        Text(
                          overview,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall!.copyWith(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ekran kilidi: bütün dokunmaları yutar. Dokununca kısa süre "Kilidi aç" çıkar.
class ScreenLockLayer extends StatelessWidget {
  const ScreenLockLayer({super.key, required this.showUnlock, required this.onTouch, required this.onUnlock});

  final bool showUnlock;
  final VoidCallback onTouch;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTouch,
    // Görüntüdeki hareketler (ses, parlaklık, sarma) kilitliyken çalışmasın.
    onScaleStart: (_) {},
    child: !showUnlock
        ? const SizedBox.expand()
        : SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: onUnlock,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xE6000000),
                    foregroundColor: Colors.white,
                  ),
                  icon: const RedoxIcon(RedoxIcons.lock, filled: true, size: 20, color: Colors.white),
                  label: const Text('Kilidi aç'),
                ),
              ),
            ),
          ),
  );
}
