import 'package:flutter/material.dart';

class OnyxCameraBridgeShellCard extends StatelessWidget {
  final Key? cardKey;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final double borderRadius;
  final Color borderColor;
  final Widget child;

  const OnyxCameraBridgeShellCard({
    super.key,
    this.cardKey,
    required this.padding,
    required this.backgroundColor,
    required this.borderRadius,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
