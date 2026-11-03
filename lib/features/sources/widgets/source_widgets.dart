import 'package:flutter/material.dart';

import '../../../core/content/user_sources.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';

// Kaynaklar bölümü ve Ayarlar > Kaynak ekle sekmesinin ortak parçaları.

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(width: 4, height: 20, color: RedoxSeeds.crimson),
        const SizedBox(width: 10),
        Text(title, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Eşit genişlikte kutular (satırlara sarılır).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.columns, required this.children, this.minWidth = 0});

  /// En çok sütun.
  final int columns;
  final List<Widget> children;

  /// Kutunun en dar genişliği (yazı ölçeğiyle büyür): dar alanda sütun
  /// azalır. TV'de Ayarlar'ın sağ bölmesinde üç sütun yazıları kesiyordu.
  final double minWidth;

  static const gap = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final least = MediaQuery.textScalerOf(context).scale(minWidth);
      final fit = ((box.maxWidth + gap) / (least + gap)).floor();
      final n = least <= 0 ? columns : fit.clamp(1, columns);
      final w = (box.maxWidth - gap * (n - 1)) / n;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

/// Kaynağın ikonu (nereden eklendiği) ve türünün rengi (Canlı TV kızıl,
/// Film altın, Dizi amber).
extension SourceLook on UserSource {
  RedoxIcons get icon => switch (origin) {
    SourceOrigin.url => RedoxIcons.link,
    SourceOrigin.json => RedoxIcons.json,
    SourceOrigin.html => RedoxIcons.html,
    SourceOrigin.xtream => RedoxIcons.profile,
    SourceOrigin.portal => RedoxIcons.portal,
    SourceOrigin.bulk => RedoxIcons.bulkAdd,
    SourceOrigin.file => RedoxIcons.uploadFile,
    SourceOrigin.phone => RedoxIcons.qrCode,
    SourceOrigin.folder => RedoxIcons.folder,
  };

  Color get tint => kindTint(kind);

  /// "240 kanal", "12 film", "86 bölüm".
  String get countLabel =>
      '$count ${switch (kind) {
        SourceKind.live => 'kanal',
        SourceKind.film => 'film',
        SourceKind.series => 'bölüm',
      }}';
}

Color kindTint(SourceKind kind) => switch (kind) {
  SourceKind.live => RedoxSeeds.crimson,
  SourceKind.film => RedoxSeeds.gold,
  SourceKind.series => RedoxSeeds.amber,
};

/// Güncelleme zamanı: "az önce", "5 dk önce", "3 sa önce", "dün", "4 gün
/// önce", sonra tarih.
String updatedLabel(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'az önce';
  if (d.inHours < 1) return '${d.inMinutes} dk önce';
  if (d.inDays < 1) return '${d.inHours} sa önce';
  if (d.inDays == 1) return 'dün';
  if (d.inDays < 7) return '${d.inDays} gün önce';
  String two(int n) => '$n'.padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)}.${at.year}';
}

/// Kaynak kartı (Kaynaklar): solda nereden eklendiğinin ikonu türün
/// rengiyle, ad, kayıt sayısı (birimi türü söyler), altta ekleme yolu ve
/// güncelleme zamanı. Kartlar eşit yükseklikte.
class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.source, required this.onPressed, this.autofocus = false});

  final UserSource source;
  final VoidCallback onPressed;
  final bool autofocus;

  static const height = 104.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = source;
    return CardShell(
      autofocus: autofocus,
      onPressed: onPressed,
      builder: (active) => Row(
        children: [
          IconTile(icon: s.icon, tint: s.tint, active: active, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                // Birim türü söyler: kanal (Canlı TV), film, bölüm (Dizi).
                Text(
                  s.countLabel,
                  maxLines: 1,
                  style: t.bodyMedium!.copyWith(
                    // Koyu zeminde kızıl yazı okunmuyor: açık birincil renk.
                    color: s.kind == SourceKind.live ? RedoxRoles.primary : s.tint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.origin.label} · ${updatedLabel(s.updated)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İlk kart: yeni kaynak (Ayarlar › Kaynak ekle).
class AddSourceCard extends StatelessWidget {
  const AddSourceCard({super.key, required this.onPressed, this.autofocus = false});

  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return CardShell(
      autofocus: autofocus,
      onPressed: onPressed,
      dashed: true,
      builder: (active) => Row(
        children: [
          IconTile(icon: RedoxIcons.add, tint: RedoxSeeds.crimson, active: active, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kaynak ekle',
                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Liste, hesap, dosya, USB/SSD',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renkli ikon karosu (kaynak kartı, ekleme yöntemi).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.tint, this.active = false, this.size = 52});

  final RedoxIcons icon;
  final Color tint;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: active ? 0.3 : 0.16),
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      border: Border.all(color: tint.withValues(alpha: 0.45)),
    ),
    // Kızıl zeminde kızıl ikon okunmuyor: açık birincil renk.
    child: RedoxIcon(icon, color: tint == RedoxSeeds.crimson ? RedoxRoles.primary : tint, size: size / 2),
  );
}

/// Kartların ortak kabuğu: odakta bir ton açık zemin ve büyüme (FocusGlow);
/// [dashed] kesik çerçeve (ekleme kartı); [selected] kızıl çerçeve.
class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.builder,
    required this.onPressed,
    this.autofocus = false,
    this.dashed = false,
    this.selected = false,
    this.height = FolderCard.height,
  });

  final Widget Function(bool active) builder;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool dashed;
  final bool selected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return FocusGlow(
      borderRadius: radius,
      builder: (context, active) => CustomPaint(
        foregroundPainter: dashed && !active ? const _DashedBorder(radius: RedoxRadius.lg) : null,
        child: Material(
          color: active
              ? RedoxRoles.surfaceContainerHighest
              : (dashed ? RedoxRoles.surfaceContainerLow : RedoxRoles.surfaceContainer),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: selected ? const BorderSide(color: RedoxSeeds.crimson, width: 2) : BorderSide.none,
          ),
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: SizedBox(
              height: height,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: builder(active)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = RedoxRoles.outline.withValues(alpha: 0.6);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.radius != radius;
}
