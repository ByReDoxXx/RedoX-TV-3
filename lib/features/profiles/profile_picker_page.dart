import 'package:flutter/material.dart';

import '../../core/content/profiles.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/ui/animated_brand_logo.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/redox_icon.dart';
import 'widgets/pin_dialog.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/profile_editor.dart';

/// "Kim izliyor?": her açılışta profil seçimi (kullanıcının YouTube TV
/// referansı). Solda "+" (profil ekle), sağında büyük renkli daireler; odaktaki
/// profilin altında düzenleme düğmesi. Koyu lacivert zeminde kızıl/amber ışıma.
///
/// PIN kuralları (ebeveyn PIN'i, ProfileStore):
/// - Çocuk profili PIN yokken açılırsa önce PIN belirlenir.
/// - Son profil çocuk profiliyse başka profil PIN ister (çocuk çıkamaz).
/// - Ekleme, düzenleme ve silme PIN ister.
class ProfilePickerPage extends StatefulWidget {
  const ProfilePickerPage({super.key, required this.store, required this.onSelected});

  final ProfileStore store;
  final ValueChanged<Profile> onSelected;

  @override
  State<ProfilePickerPage> createState() => _ProfilePickerPageState();
}

class _ProfilePickerPageState extends State<ProfilePickerPage> {
  /// Düzenleme düğmesinin altında durduğu profil (odak düğmeye inse de kalır).
  late String? _current = widget.store.byId(widget.store.lastId)?.id ?? widget.store.profiles.firstOrNull?.id;

  ProfileStore get _store => widget.store;

  /// PIN varsa sorar; yoksa geçer.
  Future<bool> _guard(String reason) async =>
      !_store.hasPin || await verifyPin(context, check: _store.checkPin, reason: reason);

  Future<void> _open(Profile p) async {
    if (p.kids && !_store.hasPin) {
      final pin = await createPin(context);
      if (pin == null) return;
      await _store.setPin(pin);
    } else if (!p.kids && _store.lockedToKids && !await _guard('Çocuk profilinden çıkılıyor.')) {
      return;
    }
    _store.select(p);
    widget.onSelected(p);
  }

  Future<void> _add() async {
    if (!_store.canAdd || !await _guard('Profil eklemek için.')) return;
    if (!mounted) return;
    final r = await showProfileEditor(context);
    if (r is! ProfileSaved) return;
    if (r.kids && !_store.hasPin) {
      if (!mounted) return;
      final pin = await createPin(context);
      if (pin == null) return;
      await _store.setPin(pin);
    }
    final p = _store.add(name: r.name, color: r.color, kids: r.kids);
    setState(() => _current = p.id);
  }

  Future<void> _edit(Profile p) async {
    if (!await _guard('Profili düzenlemek için.')) return;
    if (!mounted) return;
    switch (await showProfileEditor(context, profile: p, canDelete: _store.canRemove(p))) {
      case ProfileSaved(:final name, :final color):
        _store.update(p.copyWith(name: name, color: color));
      case ProfileDeleted():
        _store.remove(p);
        setState(() => _current = _store.profiles.firstOrNull?.id);
      case null:
    }
  }

  List<Widget> _slots(double diameter) => [
    for (final p in _store.profiles)
      _ProfileSlot(
        key: ValueKey(p.id),
        profile: p,
        diameter: diameter,
        autofocus: p.id == _current,
        showEdit: p.id == _current,
        onFocus: () => setState(() => _current = p.id),
        onPressed: () => _open(p),
        onEdit: () => _edit(p),
      ),
  ];

  /// "+" (profil ekle); yer yoksa null. Satırda profil dairelerinin ortasına
  /// hizalanır (referanstaki gibi solda); telefonda sonda.
  Widget? _add56(double diameter, {required bool inRow}) => _store.canAdd
      ? Padding(
          padding: EdgeInsets.only(top: (diameter - 56) / 2, left: inRow ? 0 : 14, right: inRow ? 20 : 14),
          child: _AddButton(onPressed: _add),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
    final diameter = phone ? 84.0 : 112.0;
    // Logo yüksekliği. TV'de 540 dp yüksekliğe logo, başlık ve profil satırı
    // birlikte sığar.
    final logo = phone ? 220.0 : 180.0;
    return Scaffold(
      backgroundColor: RedoxSeeds.obsidian,
      body: DecoratedBox(
        // Referanstaki sağ alt ışıma: logonun kızılı ve amberi.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, 1.1),
            radius: 1.2,
            colors: [Color(0x88D7232C), Color(0x33FC7422), Color(0x000B0B20)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SizedBox.expand(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) => Column(
                children: [
                  const SizedBox(height: 16),
                  // Zeminsiz tam logo: işaret ve altında "RedoX TV" yazısı
                  // (kullanıcı isteği); ışımalı zemin arkasından görünür.
                  AnimatedBrandLogo(height: logo),
                  const Spacer(),
                  Text('Kim izliyor?', style: t.headlineLarge!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 32),
                  if (phone)
                    // Telefonda dar ekran: profiller satırlara sarılır, "+" sonda.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        runSpacing: 8,
                        children: [..._slots(diameter), ?_add56(diameter, inRow: false)],
                      ),
                    )
                  else
                    // Sığarsa ortada; sığmazsa yana kayar.
                    LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: box.maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [?_add56(diameter, inRow: true), ..._slots(diameter)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSlot extends StatelessWidget {
  const _ProfileSlot({
    super.key,
    required this.profile,
    required this.diameter,
    required this.autofocus,
    required this.showEdit,
    required this.onFocus,
    required this.onPressed,
    required this.onEdit,
  });

  final Profile profile;
  final double diameter;
  final bool autofocus;
  final bool showEdit;
  final VoidCallback onFocus;
  final VoidCallback onPressed;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        width: diameter + 24,
        child: Column(
          children: [
            Semantics(
              button: true,
              label: profile.kids ? '${profile.name} (çocuk profili)' : profile.name,
              excludeSemantics: true,
              // Daire ve ad birlikte dokunulur (telefonda ada dokunmak doğal).
              child: _Focusable(
                autofocus: autofocus,
                onFocus: onFocus,
                onPressed: onPressed,
                builder: (active) => Column(
                  children: [
                    ProfileAvatar(profile: profile, diameter: diameter, active: active),
                    const SizedBox(height: 14),
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge!.copyWith(color: active ? Colors.white : RedoxRoles.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Düzenleme düğmesi yalnız seçili profilin altında; yer hep ayrılır
            // (satır zıplamasın).
            SizedBox(
              height: 48,
              child: showEdit ? IconActionButton(icon: RedoxIcons.edit, onPressed: onEdit) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Odak alan daire: odak halkası yerine beyaz halka ve büyüme (avatarın
/// kendisi çizer); D-pad/fare odağı [onFocus]'u çağırır.
class _Focusable extends StatefulWidget {
  const _Focusable({required this.autofocus, required this.onFocus, required this.onPressed, required this.builder});

  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onPressed;
  final Widget Function(bool active) builder;

  @override
  State<_Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<_Focusable> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      autofocus: widget.autofocus,
      onTap: widget.onPressed,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onHover: (v) => setState(() => _hovered = v),
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) widget.onFocus();
      },
      child: widget.builder(_focused || _hovered),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      borderRadius: BorderRadius.circular(28),
      builder: (context, active) => Material(
        color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
        shape: CircleBorder(side: active ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox.square(
            dimension: 56,
            child: Center(
              child: RedoxIcon(RedoxIcons.add, size: 30, color: active ? RedoxSeeds.obsidian : RedoxRoles.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
