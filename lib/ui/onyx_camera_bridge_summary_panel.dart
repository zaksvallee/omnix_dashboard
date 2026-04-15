import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/onyx_design_tokens.dart';

enum OnyxCameraBridgeSummaryPanelVariant { agent, admin }

class OnyxCameraBridgeSummaryPanel extends StatelessWidget {
  final Key? panelKey;
  final String summary;
  final Color? accent;
  final OnyxCameraBridgeSummaryPanelVariant variant;

  const OnyxCameraBridgeSummaryPanel({
    super.key,
    this.panelKey,
    required this.summary,
    this.accent,
    this.variant = OnyxCameraBridgeSummaryPanelVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      OnyxCameraBridgeSummaryPanelVariant.agent => Text(
        summary,
        key: panelKey,
        style: GoogleFonts.inter(
          color: OnyxColorTokens.textPrimary,
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
      OnyxCameraBridgeSummaryPanelVariant.admin => Container(
        key: panelKey,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OnyxColorTokens.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (accent ?? OnyxColorTokens.borderSubtle).withValues(
              alpha: 0.28,
            ),
          ),
        ),
        child: Text(
          summary,
          style: GoogleFonts.inter(
            color: OnyxColorTokens.textPrimary,
            fontSize: 11.3,
            fontWeight: FontWeight.w700,
            height: 1.42,
          ),
        ),
      ),
    };
  }
}
