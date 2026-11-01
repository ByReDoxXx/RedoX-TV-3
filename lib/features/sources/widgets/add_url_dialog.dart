import 'package:flutter/material.dart';

import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/tv_keyboard.dart';

/// Adresle liste ekleme: ad ve adres. TV'de uygulamanın klavyesi (sistem
/// klavyesi kumandayla gezilemiyor); hangi alana yazılacağı alan seçilerek
/// değişir. Adres alanında sembol satırı ve "https://", ".m3u" kısayolları.
Future<({String name, String url})?> showAddUrlDialog(BuildContext context) =>
    showDialog<({String name, String url})>(context: context, builder: (_) => const AddUrlDialog());

class AddUrlDialog extends StatefulWidget {
  const AddUrlDialog({super.key});

  static const maxUrl = 500;
  static const maxName = 32;

  @override
  State<AddUrlDialog> createState() => _AddUrlDialogState();
}

class _AddUrlDialogState extends State<AddUrlDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();

  /// TV'de klavyenin yazdığı alan.
  bool _editingUrl = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _url.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_url.text.trim().isEmpty) return;
    Navigator.pop(context, (name: _name.text, url: _url.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tv = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;
    final buttons = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        PrimaryButton(label: 'Ekle', icon: RedoxIcons.add, onPressed: _url.text.trim().isEmpty ? null : _submit),
        GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context)),
      ],
    );
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: tv
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adresle liste ekle', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 12 * TvKeyboard.keyExtent,
                    child: Row(
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'Ad',
                            text: _name.text,
                            selected: !_editingUrl,
                            onPressed: () => setState(() => _editingUrl = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _Field(
                            label: 'Liste adresi',
                            text: _url.text,
                            selected: _editingUrl,
                            onPressed: () => setState(() => _editingUrl = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TvKeyboard(
                        key: ValueKey(_editingUrl),
                        controller: _editingUrl ? _url : _name,
                        maxLength: _editingUrl ? AddUrlDialog.maxUrl : AddUrlDialog.maxName,
                        symbols: _editingUrl,
                        autoCapitalize: !_editingUrl,
                        autofocus: true,
                      ),
                      const SizedBox(width: 16),
                      SizedBox(width: 150, child: buttons),
                    ],
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adresle liste ekle', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _url,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'Liste adresi', hintText: 'https://.../liste.m3u'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    maxLength: AddUrlDialog.maxName,
                    decoration: const InputDecoration(labelText: 'Ad (isteğe bağlı)'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  buttons,
                ],
              ),
      ),
    );
  }
}

/// TV'de yazılamaz alan: dokununca/OK ile klavye bu alana yazar.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.text, required this.selected, required this.onPressed});

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.md);
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  text.isEmpty && !selected ? '—' : '$text${selected ? '|' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
