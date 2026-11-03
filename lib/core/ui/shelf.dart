import 'package:flutter/material.dart';

import '../theme/redox_metrics.dart';

/// Yatay raf: başlık + yatay kaydırılan öğeler, aralarında cihaz oluğu
/// (TV 48 dp). Odak ışıması raftan taşabilsin diye kırpma kapalıdır;
/// odaklanan öğe D-pad ile görünür alana kaydırılır (Flutter varsayılanı).
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.header, required this.children, this.gutter});

  final Widget header;
  final List<Widget> children;

  /// null: RedoxMetrics.gutter.
  final double? gutter;

  @override
  Widget build(BuildContext context) {
    final gap = gutter ?? Theme.of(context).extension<RedoxMetrics>()!.gutter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
            ],
          ),
        ),
      ],
    );
  }
}
