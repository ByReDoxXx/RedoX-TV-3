import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content/profiles.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import '../profiles/widgets/pin_dialog.dart';

/// Ayarlar › Ebeveyn PIN'i: PIN'i değiştir (önce mevcut, sonra yeni iki
/// kez) ya da kaldır (mevcut PIN ile; çocuk profiline sonraki girişte yenisi
/// istenir). PIN yoksa yalnız belirleme. Çocuk profilinde Ayarlar yoktur.
class ParentPinTab extends StatelessWidget {
  const ParentPinTab({super.key, required this.store, this.padding = EdgeInsets.zero});

  final ProfileStore store;
  final EdgeInsets padding;

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _change(BuildContext context) async {
    if (store.hasPin && !await verifyPin(context, check: store.checkPin, reason: 'Önce mevcut PIN.')) return;
    if (!context.mounted) return;
    final pin = await createPin(context);
    if (pin == null) return;
    await store.setPin(pin);
    if (context.mounted) _toast(context, 'Ebeveyn PIN\'i değişti.');
  }

  Future<void> _remove(BuildContext context) async {
    if (!await verifyPin(context, check: store.checkPin, reason: 'PIN kaldırılıyor.')) return;
    store.clearPin();
    if (context.mounted) _toast(context, 'Ebeveyn PIN\'i kaldırıldı.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.hasPin
                  ? 'PIN, çocuk profilinden çıkarken ve profilleri düzenlerken sorulur.'
                  : 'PIN yok. Çocuk profiline ilk girişte belirlenir; buradan da belirleyebilirsiniz.',
              style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                PrimaryButton(
                  label: store.hasPin ? 'PIN\'i değiştir' : 'PIN belirle',
                  icon: RedoxIcons.lock,
                  autofocus: true,
                  onPressed: () => unawaited(_change(context)),
                ),
                if (store.hasPin)
                  GlassButton(
                    label: 'PIN\'i kaldır',
                    icon: RedoxIcons.close,
                    onPressed: () => unawaited(_remove(context)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
