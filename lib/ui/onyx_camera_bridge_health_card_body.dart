import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'onyx_camera_bridge_detail_line.dart';

class OnyxCameraBridgeHealthCardBody extends StatelessWidget {
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final Color accent;
  final String? receiptStateLabel;
  final Color detailLineLabelColor;
  final Color detailLineValueColor;
  final double detailLineBottomPadding;
  final Color detailTextColor;
  final double detailTextFontSize;
  final double badgeFontSize;
  final double badgeLetterSpacing;
  final double? loadingTextHeight;
  final OnyxAgentCameraBridgeHealthLoadingVariant loadingVariant;

  const OnyxCameraBridgeHealthCardBody({
    super.key,
    required this.snapshot,
    required this.accent,
    required this.receiptStateLabel,
    required this.detailLineLabelColor,
    required this.detailLineValueColor,
    required this.detailLineBottomPadding,
    required this.detailTextColor,
    required this.detailTextFontSize,
    required this.badgeFontSize,
    required this.badgeLetterSpacing,
    this.loadingTextHeight,
    required this.loadingVariant,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    final healthBadge = visibleOnyxAgentCameraBridgeHealthBadge(snapshot);
    if (snapshot == null) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              describeOnyxAgentCameraBridgeHealthLoading(
                variant: loadingVariant,
              ),
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                height: loadingTextHeight,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          healthBadge!.label,
          style: GoogleFonts.inter(
            color: accent,
            fontSize: badgeFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: badgeLetterSpacing,
          ),
        ),
        const SizedBox(height: 8),
        ...visibleOnyxAgentCameraBridgeHealthFields(
          snapshot: snapshot,
          receiptStateLabel: receiptStateLabel!,
          checkedAtLabel: formatOnyxAgentCameraBridgeCheckedAtLabel(
            snapshot.checkedAtUtc,
          ),
        ).map(
          (field) => OnyxCameraBridgeDetailLine(
            label: field.label,
            value: field.value,
            labelColor: detailLineLabelColor,
            valueColor: detailLineValueColor,
            bottomPadding: detailLineBottomPadding,
          ),
        ),
        Text(
          snapshot.detail,
          style: GoogleFonts.inter(
            color: detailTextColor,
            fontSize: detailTextFontSize,
            fontWeight: FontWeight.w600,
            height: 1.42,
          ),
        ),
      ],
    );
  }
}
