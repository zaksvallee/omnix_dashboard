import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'onyx_camera_bridge_health_card_body.dart';

class OnyxCameraBridgeHealthCard extends StatelessWidget {
  final Key? cardKey;
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final Color accent;
  final Color backgroundColor;
  final double borderAlpha;
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

  const OnyxCameraBridgeHealthCard({
    super.key,
    this.cardKey,
    required this.snapshot,
    required this.accent,
    required this.backgroundColor,
    this.borderAlpha = 0.35,
    required this.receiptStateLabel,
    required this.detailLineLabelColor,
    required this.detailLineValueColor,
    required this.detailLineBottomPadding,
    required this.detailTextColor,
    required this.detailTextFontSize,
    required this.badgeFontSize,
    required this.badgeLetterSpacing,
    required this.loadingTextHeight,
    required this.loadingVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: borderAlpha)),
      ),
      child: OnyxCameraBridgeHealthCardBody(
        snapshot: snapshot,
        accent: accent,
        receiptStateLabel: receiptStateLabel,
        detailLineLabelColor: detailLineLabelColor,
        detailLineValueColor: detailLineValueColor,
        detailLineBottomPadding: detailLineBottomPadding,
        detailTextColor: detailTextColor,
        detailTextFontSize: detailTextFontSize,
        badgeFontSize: badgeFontSize,
        badgeLetterSpacing: badgeLetterSpacing,
        loadingTextHeight: loadingTextHeight,
        loadingVariant: loadingVariant,
      ),
    );
  }
}
