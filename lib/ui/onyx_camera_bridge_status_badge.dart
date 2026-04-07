import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnyxCameraBridgeStatusBadge extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double? letterSpacing;

  const OnyxCameraBridgeStatusBadge({
    super.key,
    required this.label,
    required this.foregroundColor,
    required this.borderColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    this.fontSize = 9.8,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}
