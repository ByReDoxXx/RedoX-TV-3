import 'package:flutter/material.dart';

import '../../core/content/content_locks.dart';
import '../../core/content/profiles.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/redox_icon.dart';
import '../profiles/widgets/pin_dialog.dart';

/// Kilitler ve ebeveyn PIN'i (RootShell sağlar). Kilitli kanal ya da klasör
/// açılırken [pass] PIN sorar; kilit koymak/kaldırmak da PIN ister ([toggle]).
class LockScope extends InheritedNotifier<ContentLocks> {
  const LockScope({super.key, required ContentLocks locks, required this.profiles, required super.child})
    : super(notifier: locks);

  final ProfileStore? profiles;

  ContentLocks get locks => notifier!;

  static LockScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LockScope>();

  /// [key] kilitliyse PIN sorar; doğrulanırsa oturum boyunca açar. PIN
  /// belirlenmemişse kilit uygulanamaz (true).
  Future<bool> pass(BuildContext context, String key) async {
    if (!locks.blocks(key)) return true;
    final p = profiles;
    if (p == null || !p.hasPin) return true;
    final ok = await verifyPin(context, check: p.checkPin, reason: 'Bu içerik kilitli.');
    if (ok) locks.unlock(key);
    return ok;
  }

  /// Kilidi koyar ya da kaldırır; önce PIN (yoksa belirletir).
  Future<void> toggle(BuildContext context, String key) async {
    final p = profiles;
    if (p == null) return;
    if (!p.hasPin) {
      final pin = await createPin(context);
      if (pin == null) return;
      await p.setPin(pin);
    } else if (!context.mounted ||
        !await verifyPin(
          context,
          check: p.checkPin,
          reason: locks.isLocked(key) ? 'Kilidi kaldırmak için' : 'Kilitlemek için',
        )) {
      return;
    }
    locks.toggle(key);
  }
}

/// Kilit düğmesi: kilitliyse dolu kilit (kızıl). [LockScope] yoksa çizilmez.
class LockButton extends StatelessWidget {
  const LockButton({super.key, required this.lockKey, this.size = 44});

  final String lockKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = LockScope.maybeOf(context);
    if (scope == null || scope.profiles == null) return const SizedBox.shrink();
    final locked = scope.locks.isLocked(lockKey);
    return Semantics(
      button: true,
      label: locked ? 'Kilidi kaldır' : 'Kilitle',
      excludeSemantics: true,
      child: FocusGlow(
        borderRadius: BorderRadius.circular(size / 2),
        builder: (context, active) => Material(
          color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
          shape: CircleBorder(side: active ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder)),
          child: InkWell(
            onTap: () => scope.toggle(context, lockKey),
            customBorder: const CircleBorder(),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: RedoxIcon(
                  RedoxIcons.lock,
                  filled: locked,
                  color: active ? RedoxSeeds.obsidian : (locked ? RedoxRoles.primary : RedoxRoles.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
