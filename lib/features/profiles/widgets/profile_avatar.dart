import 'package:flutter/material.dart';

import '../../../core/content/profiles.dart';
import '../../../core/theme/m3e_motion.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_icon.dart';

/// Profil dairesi: renkli zemin ve adın baş harfi (kullanıcının YouTube TV
/// referansı). Odakta beyaz halka ve büyüme; çocuk profilinde köşede çocuk
/// rozeti.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.diameter = 112, this.active = false});

  /// Avatar renkleri: marka tonları (kızıl, kor, altın) ve ayırt edilsin diye
  /// üç soğuk ton. Beyaz harf hepsinde okunur (koyu T40 tonları).
  static const colors = [
    RedoxSeeds.crimson,
    RedoxAccent.ember,
    RedoxRoles.tertiaryContainer,
    Color(0xFF6B3FA0),
    Color(0xFF00796B),
    Color(0xFF1E5BB8),
  ];

  static Color colorOf(int index) => colors[index % colors.length];

  final Profile profile;
  final double diameter;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ring = diameter * 0.045;
    return AnimatedScale(
      scale: active ? 1.08 : 1,
      duration: M3EMotion.short4,
      curve: M3EMotion.standard,
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: M3EMotion.short4,
              padding: EdgeInsets.all(ring),
              decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Colors.white : Colors.transparent),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: colorOf(profile.color)),
                alignment: Alignment.center,
                child: Text(
                  profile.initial,
                  style: TextStyle(
                    fontSize: diameter * 0.42,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (profile.kids)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: diameter * 0.32,
                  height: diameter * 0.32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: RedoxSeeds.gold,
                    border: Border.all(color: RedoxSeeds.obsidian, width: 3),
                  ),
                  child: Center(
                    child: RedoxIcon(RedoxIcons.kids, filled: true, color: RedoxSeeds.obsidian, size: diameter * 0.18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
