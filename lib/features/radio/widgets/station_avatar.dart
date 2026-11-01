import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/channel_logo.dart';

/// İstasyon karosu: yuvarlak köşeli kare; logo, yoksa adın baş harfleri.
class StationAvatar extends StatelessWidget {
  const StationAvatar({super.key, required this.station, this.size = 44, this.radius = RedoxRadius.md});

  final LiveChannel station;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: ChannelLogo(name: station.name, logoUrl: station.logoUrl, size: 1),
      ),
    );
  }
}
