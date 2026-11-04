import 'package:flutter/material.dart';

import '../../../core/layout/mouse_mode.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/platform/system_text_input.dart';

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
/// alanlar alt alta; OK cihazın kendi klavyesiyle yerel metin kutusunu açar
/// ([SystemTextInput]; kullanıcı isteği: varsayılan klavye). Telefonda normal
/// metin alanları. Sonuç alan anahtarı → değer.
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
    Navigator.pop(context, {for (final f in widget.fields) f.key: _value(f)});
  }

  /// Gönderilen değer. Adres ve MAC'te boşluk olamaz: telefon klavyesi
  /// noktadan sonra boşluk ekleyebiliyor ("github. io"; cihazda görüldü).
  String _value(FormFieldSpec f) {
    final text = _controllers[f.key]!.text.trim();
    return switch (f.kind) {
      FieldKind.url => text.replaceAll(RegExp(r'\s'), ''),
      FieldKind.mac => text.replaceAll(RegExp(r'\s'), '').toUpperCase(),
      _ => text,
    };
  }

  static int _max(FieldKind k) => switch (k) {
    FieldKind.url => 500,
    FieldKind.mac => 17,
    _ => 64,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tv = usesSystemTextInput(context);
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

  /// TV: alana OK'e basılınca cihazın kendi klavyesiyle yerel kutu açılır.
  Future<void> _edit(FormFieldSpec f) async {
    final text = await SystemTextInput.ask(
      title: f.label,
      value: _controllers[f.key]!.text,
      kind: switch (f.kind) {
        FieldKind.url => TextKind.url,
        FieldKind.secret => TextKind.secret,
        FieldKind.mac => TextKind.mac,
        FieldKind.text => TextKind.text,
      },
      maxLength: _max(f.kind),
    );
    if (text != null && mounted) _controllers[f.key]!.text = text.trim();
  }

  Widget _tvBody(List<Widget> head, Widget buttons) => SizedBox(
    width: 620,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...head,
        const SizedBox(height: 14),
        for (final (i, f) in widget.fields.indexed) ...[
          _Field(spec: f, text: _controllers[f.key]!.text, autofocus: i == 0, onPressed: () => _edit(f)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        buttons,
      ],
    ),
  );

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
          // Adres, MAC, şifre: otomatik düzeltme ve öneri yok.
          autocorrect: f.kind == FieldKind.text,
          enableSuggestions: f.kind == FieldKind.text,
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

/// TV'de alan: OK/dokunma sistem klavyesini açar.
class _Field extends StatelessWidget {
  const _Field({required this.spec, required this.text, required this.onPressed, this.autofocus = false});

  final FormFieldSpec spec;
  final String text;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
    final shown = spec.kind == FieldKind.secret ? '•' * text.length : text;
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: active ? RedoxSeeds.amber : RedoxRoles.outlineVariant, width: active ? 2 : 1),
        ),
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.required ? spec.label : '${spec.label} (isteğe bağlı)',
                        style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.isEmpty ? (spec.hint ?? '—') : shown,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyLarge!.copyWith(color: text.isEmpty ? RedoxRoles.outline : RedoxRoles.onSurface),
                      ),
                    ],
                  ),
                ),
                RedoxIcon(RedoxIcons.edit, size: 20, color: active ? RedoxSeeds.amber : RedoxRoles.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
