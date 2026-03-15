import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportSceneReviewNarrativeBox extends StatelessWidget {
  final String narrative;
  final Color accent;

  const ReportSceneReviewNarrativeBox({
    super.key,
    required this.narrative,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedNarrative = narrative.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        normalizedNarrative.isEmpty
            ? 'Scene review detail pending.'
            : normalizedNarrative,
        style: GoogleFonts.inter(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
