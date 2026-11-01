import 'package:flutter/material.dart';

import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/tv_keyboard.dart';

/// Alanın türü: klavye ve gösterim buna göre.
enum FieldKind {
  /// Ad: kelime başı büyük harf.
  text,

  /// Adres: sembol satırı, "https://", büyük harf yok.
  url,

  /// Şifre: noktalı gösterim.
  secret,

  /// MAC: sembol satırı (:), gönderirken büyük harfe çevrilir.
  mac,
}

@immutable
class FormFieldSpec {
  const FormFieldSpec(this.key, this.label, {this.kind = FieldKind.text, this.required = true, this.hint});

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final String? hint;
}

/// Kaynak ekleme formu (M3U, JSON, HTML, Xtream, Portal, Toplu). TV'de
/// uygulamanın klavyesi: alan seçilir, klavye ona yazar (sistem klavyesi
/// kumandayla gezilemiyor). Sonuç alan anahtarı → değer.
Future<Map<String, String>?> showSourceForm(
  BuildContext context, {
  required String title,
  required String description,
  required List<FormFieldSpec> fields,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => SourceFormDialog(title: title, description: description, fields: fields),
);

class SourceFormDialog extends StatefulWidget {
  const SourceFormDialog({super.key, required this.title, required this.description, required this.fields});

  final String title;
  final String description;
  final List<FormFieldSpec> fields;

  @override
  State<SourceFormDialog> createState() => _SourceFormDialogState();
}

class _SourceFormDialogState extends State<SourceFormDialog> {
  late final _controllers = {for (final f in widget.fields) f.key: TextEditingController()};
  late int _active = widget.fields.indexWhere((f) => f.required).clamp(0, widget.fields.length - 1);

  @override
  void initState() {
    super.initState();
    for (final c in _controllers.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ready => widget.fields.every((f) => !f.required || _controllers[f.key]!.text.trim().isNotEmpty);

  void _submit() {
    if (!_ready) return;
    Navigator.pop(context, {
      for (final f in widget.fields)
        f.key: f.kind == FieldKind.mac
            ? _controllers[f.key]!.text.trim().toUpperCase()
            : _controllers[f.key]!.text.trim(),
    });
  }

  static int _max(FieldKind k) => switch (k) {
    FieldKind.url => 500,
    FieldKind.mac => 17,
    _ => 64,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tv = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;
    final buttons = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrimaryButton(label: 'Ekle', icon: RedoxIcons.add, onPressed: _ready ? _submit : null),
        GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context)),
      ],
    );
    final head = [
      Text(widget.title, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
      const SizedBox(height: 4),
      Text(widget.description, style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
    ];
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: tv ? _tvBody(head, buttons) : _phoneBody(head, buttons),
      ),
    );
  }

  Widget _tvBody(List<Widget> head, Widget buttons) {
    final spec = widget.fields[_active];
    const width = 12 * TvKeyboard.keyExtent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: width + 166,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: head),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: width,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, f) in widget.fields.indexed)
                SizedBox(
                  width: widget.fields.length == 1 ? width : (width - 8) / 2,
                  child: _Field(
                    spec: f,
                    text: _controllers[f.key]!.text,
                    selected: i == _active,
                    onPressed: () => setState(() => _active = i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            TvKeyboard(
              key: ValueKey(_active),
              controller: _controllers[spec.key]!,
              maxLength: _max(spec.kind),
              symbols: spec.kind == FieldKind.url || spec.kind == FieldKind.mac,
              autoCapitalize: spec.kind == FieldKind.text,
              autofocus: true,
            ),
            const SizedBox(width: 16),
            SizedBox(width: 150, child: buttons),
          ],
        ),
      ],
    );
  }

  Widget _phoneBody(List<Widget> head, Widget buttons) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...head,
      for (final (i, f) in widget.fields.indexed) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _controllers[f.key],
          autofocus: i == 0,
          obscureText: f.kind == FieldKind.secret,
          keyboardType: f.kind == FieldKind.url ? TextInputType.url : TextInputType.text,
          textCapitalization: f.kind == FieldKind.mac ? TextCapitalization.characters : TextCapitalization.none,
          decoration: InputDecoration(labelText: f.required ? f.label : '${f.label} (isteğe bağlı)', hintText: f.hint),
        ),
      ],
      const SizedBox(height: 16),
      buttons,
    ],
  );
}

/// TV'de yazılamaz alan: OK/dokunma ile klavye bu alana yazar.
class _Field extends StatelessWidget {
  const _Field({required this.spec, required this.text, required this.selected, required this.onPressed});

  final FormFieldSpec spec;
  final String text;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final shown = spec.kind == FieldKind.secret ? '•' * text.length : text;
    final empty = text.isEmpty && !selected;
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: RedoxRoles.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? RedoxSeeds.amber : RedoxRoles.outlineVariant, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.required ? spec.label : '${spec.label} (isteğe bağlı)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? (spec.hint ?? '—') : '$shown${selected ? '|' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge!.copyWith(color: empty ? RedoxRoles.outline : RedoxRoles.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
