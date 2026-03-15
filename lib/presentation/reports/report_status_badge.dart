import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportStatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const ReportStatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLabel = label.trim();
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        normalizedLabel,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
