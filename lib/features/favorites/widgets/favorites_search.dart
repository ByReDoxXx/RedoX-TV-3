import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/layout/mouse_mode.dart';
import '../../../core/platform/system_text_input.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';

/// Favorilerde arama. TV: düğme cihazın klavyesini açar, boş onay aramayı
/// temizler. Dokunmatik ve masaüstü: kutu, yazdıkça süzer.
class FavoritesSearch extends StatefulWidget {
  const FavoritesSearch({super.key, required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<FavoritesSearch> createState() => _FavoritesSearchState();
}

class _FavoritesSearchState extends State<FavoritesSearch> {
  late final _text = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(FavoritesSearch old) {
    super.didUpdateWidget(old);
    // Sayfadaki "Aramayı temizle" kutuyu da boşaltır.
    if (widget.query != _text.text) _text.text = widget.query;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = await SystemTextInput.ask(title: 'Favorilerde ara', value: widget.query);
    if (q != null && mounted) widget.onChanged(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (usesSystemTextInput(context)) {
      return GlassButton(
        // Uzun arama metni sekmeleri ekrandan itmesin.
        label: switch (widget.query) {
          '' => 'Ara',
          final q when q.length > 12 => '${q.substring(0, 12)}…',
          final q => q,
        },
        icon: RedoxIcons.search,
        onPressed: () => unawaited(_ask()),
      );
    }
    final t = Theme.of(context).textTheme;
    final pill = BorderRadius.circular(RedoxRadius.full);
    return TextField(
      controller: _text,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurface),
      decoration: InputDecoration(
        hintText: 'Favorilerde ara',
        hintStyle: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: RedoxIcon(RedoxIcons.search, size: 20, color: RedoxRoles.tertiary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Aramayı temizle',
                icon: const RedoxIcon(RedoxIcons.close, size: 18, color: RedoxRoles.onSurfaceVariant),
                onPressed: () => widget.onChanged(''),
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: pill,
          borderSide: BorderSide(color: RedoxRoles.outlineVariant.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: pill,
          borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
        ),
      ),
    );
  }
}
