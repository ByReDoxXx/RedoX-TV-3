import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/category_chip.dart';
import '../../../core/ui/center_on_focus.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../sources/widgets/source_widgets.dart';

/// Ayar bölümünün gövdesi: başlık ve alt alta ayarlar; kendi içinde kayar.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.title, required this.children, this.padding = EdgeInsets.zero});

  final String title;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title),
        // D-pad odağında ayar ortalanır: kenara yaslanınca büyüyen çip ve
        // halkası kesiliyordu.
        for (final c in children)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: CenterOnFocus(child: c),
          ),
      ],
    ),
  );
}

/// Ayarın adı ve (varsa) açıklaması; altında denetimi.
class SettingTile extends StatelessWidget {
  const SettingTile({super.key, required this.title, this.description, required this.child});

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(description!, style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Seçenekli ayar: seçenekler çip olarak (kumandayla gezilir, OK seçer).
class ChoiceSetting<T> extends StatelessWidget {
  const ChoiceSetting({
    super.key,
    required this.title,
    this.description,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final String? description;
  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SettingTile(
    title: title,
    description: description,
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final v in values) CategoryChip(label: labelOf(v), selected: v == selected, onPressed: () => onChanged(v)),
      ],
    ),
  );
}

/// Açık/Kapalı ayarı.
class SwitchSetting extends StatelessWidget {
  const SwitchSetting({super.key, required this.title, this.description, required this.value, required this.onChanged});

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceSetting<bool>(
    title: title,
    description: description,
    values: const [true, false],
    labelOf: (v) => v ? 'Açık' : 'Kapalı',
    selected: value,
    onChanged: onChanged,
  );
}

/// Düğmeli ayar (temizle, yedekle...).
class ActionSetting extends StatelessWidget {
  const ActionSetting({
    super.key,
    required this.title,
    this.description,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String title;
  final String? description;
  final String label;
  final RedoxIcons icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => SettingTile(
    title: title,
    description: description,
    child: primary
        ? PrimaryButton(label: label, icon: icon, onPressed: onPressed)
        : GlassButton(label: label, icon: icon, onPressed: onPressed),
  );
}

/// Bilgi satırı (Hakkında): ad solda, değer sağda.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value, style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurface)),
        ),
      ],
    );
  }
}

/// Onay penceresi; evet ise true.
Future<bool> confirmSetting(
  BuildContext context, {
  required String title,
  required String text,
  String yes = 'Sil',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: RedoxRoles.surfaceContainerHigh,
        title: Text(title),
        content: Text(text),
        actions: [
          GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context, false)),
          PrimaryButton(label: yes, autofocus: true, onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    ) ??
    false;

void settingToast(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
