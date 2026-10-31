import 'package:flutter/material.dart';

import '../../../core/content/profiles.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import 'profile_avatar.dart';

/// Düzenleyicinin sonucu: kaydet (ad, renk, çocuk mu) ya da sil.
sealed class ProfileEdit {
  const ProfileEdit();
}

final class ProfileSaved extends ProfileEdit {
  const ProfileSaved({required this.name, required this.color, required this.kids});

  final String name;
  final int color;
  final bool kids;
}

final class ProfileDeleted extends ProfileEdit {
  const ProfileDeleted();
}

/// Profil ekler ([profile] null) ya da düzenler. Çocuk profili yalnız
/// eklerken seçilir (sonradan değişirse PIN kuralı delinir).
Future<ProfileEdit?> showProfileEditor(BuildContext context, {Profile? profile, bool canDelete = false}) =>
    showDialog<ProfileEdit>(
      context: context,
      builder: (_) => ProfileEditor(profile: profile, canDelete: canDelete),
    );

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.profile, this.canDelete = false});

  final Profile? profile;
  final bool canDelete;

  static const maxName = 16;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  late int _color = widget.profile?.color ?? 1;
  late bool _kids = widget.profile?.kids ?? false;

  bool get _adding => widget.profile == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, ProfileSaved(name: name, color: _color, kids: _kids));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final preview = Profile(id: '', name: _name.text.isEmpty ? '?' : _name.text, color: _color, kids: _kids);
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(profile: preview, diameter: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _adding ? 'Profil ekle' : 'Profili düzenle',
                      style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                autofocus: _adding,
                maxLength: ProfileEditor.maxName,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 8),
              Text('Renk', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < ProfileAvatar.colors.length; i++)
                    _Swatch(
                      color: ProfileAvatar.colors[i],
                      selected: i == _color,
                      onPressed: () => setState(() => _color = i),
                    ),
                ],
              ),
              if (_adding) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _kids,
                  onChanged: (v) => setState(() => _kids = v),
                  title: Text('Çocuk profili', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
                  subtitle: Text(
                    'Yalnız Çocuk kategorisi; çıkışta PIN sorulur.',
                    style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  PrimaryButton(
                    label: 'Kaydet',
                    icon: RedoxIcons.check,
                    onPressed: _name.text.trim().isEmpty ? null : _save,
                  ),
                  GlassButton(label: 'Vazgeç', onPressed: () => Navigator.pop(context)),
                  if (!_adding && widget.canDelete)
                    GlassButton(
                      label: 'Sil',
                      icon: RedoxIcons.close,
                      onPressed: () => Navigator.pop(context, const ProfileDeleted()),
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

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onPressed});

  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      borderRadius: BorderRadius.circular(20),
      builder: (context, _) => Material(
        color: color,
        shape: CircleBorder(side: selected ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox.square(
            dimension: 40,
            child: selected ? const Center(child: RedoxIcon(RedoxIcons.check, color: Colors.white, size: 20)) : null,
          ),
        ),
      ),
    );
  }
}
