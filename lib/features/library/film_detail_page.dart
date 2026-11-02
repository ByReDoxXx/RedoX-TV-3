import 'package:flutter/material.dart';

import '../../core/content/live_channel.dart';
import '../../core/content/tmdb.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'widgets/rating_line.dart';
import 'widgets/tmdb_poster.dart';

/// Film ayrıntısı (TMDB): arka plan görseli, afiş, ad, yıl, puan, kategori ve
/// özet; "İzle" (odakta) filmi oynatır. TMDB'de bulunamazsa listedeki ad ve
/// afişle açılır.
class FilmDetailPage extends StatelessWidget {
  const FilmDetailPage({super.key, required this.film, required this.tmdb, this.onWatch});

  final LiveChannel film;
  final Tmdb tmdb;
  final VoidCallback? onWatch;

  static Route<void> route({required LiveChannel film, required Tmdb tmdb, VoidCallback? onWatch}) => MaterialPageRoute(
    builder: (_) => FilmDetailPage(film: film, tmdb: tmdb, onWatch: onWatch),
  );

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder(
        future: tmdb.find(film.name, series: false),
        builder: (context, snap) {
          final info = snap.data;
          final backdrop = info?.backdrop;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (backdrop != null)
                Image.network(backdrop, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: _fade(Theme.of(context).scaffoldBackgroundColor, [1, 0.9, 0.4]),
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(phone ? 16 : 48),
                  child: phone ? _phone(context, info) : _wide(context, info),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Arka plan renginin saydamlık basamakları (görselin üstündeki geçiş).
  static List<Color> _fade(Color bg, List<double> alphas) => [for (final a in alphas) bg.withValues(alpha: a)];

  Widget _poster(TmdbInfo? info, double width) => ClipRRect(
    borderRadius: BorderRadius.circular(RedoxRadius.lg),
    child: SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: TmdbPoster(name: film.name, url: film.logoUrl ?? info?.poster),
      ),
    ),
  );

  Widget _wide(BuildContext context, TmdbInfo? info) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _poster(info, 240),
      const SizedBox(width: 40),
      Expanded(child: _text(context, info, maxLines: 8)),
    ],
  );

  Widget _phone(BuildContext context, TmdbInfo? info) => ListView(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: GlassButton(
          label: 'Geri',
          icon: RedoxIcons.back,
          iconOnly: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      const SizedBox(height: 16),
      Center(child: _poster(info, 180)),
      const SizedBox(height: 24),
      _text(context, info),
    ],
  );

  Widget _text(BuildContext context, TmdbInfo? info, {int? maxLines}) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(info?.title ?? film.name, style: t.displaySmall!.copyWith(color: RedoxRoles.onSurface)),
        if (info != null && info.title != film.name) ...[
          const SizedBox(height: 4),
          Text(film.name, style: t.bodyMedium!.copyWith(color: RedoxRoles.outline)),
        ],
        const SizedBox(height: 12),
        RatingLine(
          info: info,
          extra: [film.category],
          style: t.titleMedium!.copyWith(color: RedoxRoles.tertiary),
        ),
        if (info != null && info.overview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            info.overview,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant, height: 1.5),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            PrimaryButton(
              label: 'İzle',
              icon: RedoxIcons.play,
              autofocus: true,
              // Sayfa açık kalır: oynatıcıdan Geri film sayfasına döner.
              onPressed: onWatch,
            ),
          ],
        ),
      ],
    );
  }
}
