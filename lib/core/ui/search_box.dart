import 'dart:async';

import 'package:flutter/material.dart';

import '../layout/mouse_mode.dart';
import '../platform/system_text_input.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'redox_buttons.dart';
import 'redox_icon.dart';

/// Sayfa içi arama (Favoriler, Kaynaklar). TV: düğme cihazın klavyesini açar,
/// boş onay aramayı temizler. Dokunmatik ve masaüstü: kutu, yazdıkça süzer.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.query, required this.hint, required this.onChanged});

  final String query;

  /// Kutunun ipucu, TV'de klavye penceresinin başlığı.
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final _text = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(SearchBox old) {
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
    final q = await SystemTextInput.ask(title: widget.hint, value: widget.query);
    if (q != null && mounted) widget.onChanged(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (usesSystemTextInput(context)) {
      return GlassButton(
        // Uzun arama metni yandaki düğmeleri ekrandan itmesin.
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
        hintText: widget.hint,
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
