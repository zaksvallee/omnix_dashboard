import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OnyxCameraBridgeValidationSummary extends StatelessWidget {
  final String? summary;
  final Color color;
  final double topSpacing;
  final double fontSize;
  final double height;

  const OnyxCameraBridgeValidationSummary({
    super.key,
    required this.summary,
    required this.color,
    this.topSpacing = 8,
    this.fontSize = 10.9,
    this.height = 1.35,
  });

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topSpacing),
        Text(
          summary!,
          style: GoogleFonts.inter(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: height,
          ),
        ),
      ],
    );
  }
}
