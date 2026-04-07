import 'package:flutter/material.dart';

class OnyxCameraBridgeChipWrap extends StatelessWidget {
  final Widget? leading;
  final List<Widget> chips;
  final double spacing;
  final double runSpacing;

  const OnyxCameraBridgeChipWrap({
    super.key,
    this.leading,
    required this.chips,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [?leading, ...chips],
    );
  }
}
