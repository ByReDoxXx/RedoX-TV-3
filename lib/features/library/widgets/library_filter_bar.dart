import 'package:flutter/material.dart';

import '../../../core/content/library_filter.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/category_chip.dart';
import '../../../core/ui/scroll_hint_row.dart';

/// Film/Dizi ızgarasının üstündeki süzgeç satırı: Kategori, Tür ve Yıl
/// çipleri (seçiliyse değeriyle, kızıl), süzgeç varken "Temizle" ve sonuç
/// sayısı. Çip seçenek panelini açar; yalnız listede karşılığı olan süzgeç
/// görünür.
class LibraryFilterBar<T> extends StatelessWidget {
  const LibraryFilterBar({
    super.key,
    required this.index,
    required this.filter,
    required this.count,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final FilterIndex<T> index;
  final LibraryFilter filter;

  /// Süzgeçle eşleşen kayıt sayısı.
  final int count;
  final ValueChanged<LibraryFilter> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    Future<void> pick<V>(
      String title,
      List<List<FilterOption<V>>> sections,
      V? selected,
      LibraryFilter Function(V?) to,
    ) async {
      final picked = await showFilterPicker<V>(context, title: title, sections: sections, selected: selected);
      if (picked != null) onChanged(to(picked.$1));
    }

    final chips = <Widget>[
      if (index.hasCategories)
        CategoryChip(
          label: filter.category == null ? 'Kategori' : 'Kategori: ${filter.category}',
          selected: filter.category != null,
          onPressed: () => pick('Kategori', [index.categories(filter)], filter.category, filter.withCategory),
        ),
      if (index.hasGenres)
        CategoryChip(
          label: filter.genre == null ? 'Tür' : 'Tür: ${filter.genre}',
          selected: filter.genre != null,
          onPressed: () => pick('Tür', [index.genres(filter)], filter.genre, filter.withGenre),
        ),
      if (index.hasYears)
        CategoryChip(
          label: filter.years == null ? 'Yıl' : 'Yıl: ${filter.years!.label}',
          selected: filter.years != null,
          onPressed: () => pick('Yıl', index.years(filter), filter.years, filter.withYears),
        ),
      if (!filter.isEmpty) CategoryChip(label: 'Temizle', onPressed: () => onChanged(const LibraryFilter())),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return ScrollHintRow(
      padding: padding,
      child: Row(
        children: [
          for (final (i, chip) in chips.indexed) ...[if (i > 0) const SizedBox(width: 12), chip],
          const SizedBox(width: 16),
          Text('$count kayıt', style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Süzgeç seçenekleri: TV/tablette sağda yan panel, telefonda alt sayfa.
/// Bölümler alt alta, her bölüm çip satırları (Yıl'da onyıl başına bir
/// bölüm). Seçilen değer kayıtla döner (`(null,)`: Tümü); kapatılırsa null.
Future<(V?,)?> showFilterPicker<V>(
  BuildContext context, {
  required String title,
  required List<List<FilterOption<V>>> sections,
  V? selected,
}) {
  final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
  final panel = FilterPicker<V>(title: title, sections: sections, selected: selected);
  if (phone) {
    return showModalBottomSheet<(V?,)>(
      context: context,
      showDragHandle: true,
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: SafeArea(child: panel),
      ),
    );
  }
  return showGeneralDialog<(V?,)>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: const Color(0x99000000),
    pageBuilder: (_, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: RedoxRoles.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(RedoxRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 520, child: panel),
        ),
      ),
    ),
  );
}

class FilterPicker<V> extends StatelessWidget {
  const FilterPicker({super.key, required this.title, required this.sections, this.selected});

  final String title;
  final List<List<FilterOption<V>>> sections;
  final V? selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
          for (final options in sections) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final o in options)
                  CategoryChip(
                    label: o.label,
                    count: o.count,
                    selected: o.value == selected,
                    // Odak açılışta seçili seçenekte (Tümü dahil).
                    autofocus: o.value == selected,
                    onPressed: () => Navigator.pop(context, (o.value,)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
