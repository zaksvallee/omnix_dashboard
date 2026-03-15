import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportMetaPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double backgroundOpacity;
  final double borderOpacity;

  const ReportMetaPill({
    super.key,
    required this.label,
    required this.color,
    this.isActive = false,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.backgroundOpacity = 0.14,
    this.borderOpacity = 0.42,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLabel = label.trim();
    final resolvedBackgroundOpacity = isActive
        ? (backgroundOpacity < 0.26 ? 0.26 : backgroundOpacity)
        : backgroundOpacity;
    final resolvedBorderOpacity = isActive
        ? (borderOpacity < 0.75 ? 0.75 : borderOpacity)
        : borderOpacity;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: resolvedBackgroundOpacity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: resolvedBorderOpacity)),
      ),
      child: Text(
        normalizedLabel,
        style: GoogleFonts.inter(
          color: color,
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
    );
  }
}
