import 'package:flutter/material.dart';

import '../../core/remote/remote_input.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';

/// TV: telefon kumandası bağlıyken yazı telefondan gelir (cihaz klavyesi
/// açılmaz). Telefondaki Klavye ile yazılan metin kutuda görünür; Tamam
/// (odakta) metni verir, Vazgeç/Geri null.
class RemoteTextDialog extends StatefulWidget {
  const RemoteTextDialog({super.key, required this.title, this.value = '', this.secret = false});

  final String title;
  final String value;

  /// Şifre: noktalı gösterilir.
  final bool secret;

  static Future<String?> show(BuildContext context, {required String title, String value = '', bool secret = false}) =>
      showDialog<String>(
        context: context,
        builder: (_) => RemoteTextDialog(title: title, value: value, secret: secret),
      );

  @override
  State<RemoteTextDialog> createState() => _RemoteTextDialogState();
}

class _RemoteTextDialogState extends State<RemoteTextDialog> {
  late final _text = ValueNotifier(widget.value);

  @override
  void initState() {
    super.initState();
    RemoteInput.textTarget = _text;
  }

  @override
  void dispose() {
    if (RemoteInput.textTarget == _text) RemoteInput.textTarget = null;
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const RedoxIcon(RedoxIcons.remote, size: 20, color: RedoxRoles.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Telefondaki kumandada Klavye ile yazın.',
                      style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: RedoxRoles.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RedoxRoles.primaryContainer, width: 2),
                ),
                child: ValueListenableBuilder(
                  valueListenable: _text,
                  builder: (context, text, _) => Text(
                    text.isEmpty ? 'Yazı bekleniyor…' : (widget.secret ? '•' * text.length : text),
                    style: t.titleLarge!.copyWith(color: text.isEmpty ? RedoxRoles.outline : RedoxRoles.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassButton(label: 'Vazgeç', onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: 'Tamam',
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(_text.value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
