import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'theme/onyx_design_tokens.dart';
import 'onyx_camera_bridge_health_card.dart';

enum OnyxCameraBridgeHealthPanelVariant { agent, admin }

class OnyxCameraBridgeHealthPanel extends StatelessWidget {
  final Key? cardKey;
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final Color accent;
  final String? receiptStateLabel;
  final OnyxCameraBridgeHealthPanelVariant variant;

  const OnyxCameraBridgeHealthPanel({
    super.key,
    this.cardKey,
    required this.snapshot,
    required this.accent,
    required this.receiptStateLabel,
    this.variant = OnyxCameraBridgeHealthPanelVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeHealthCard(
      cardKey: cardKey,
      snapshot: snapshot,
      accent: accent,
      backgroundColor: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent =>
          OnyxColorTokens.backgroundSecondary,
        OnyxCameraBridgeHealthPanelVariant.admin =>
          OnyxColorTokens.surfaceElevated,
      },
      borderAlpha: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 0.18,
        OnyxCameraBridgeHealthPanelVariant.admin => 0.18,
      },
      receiptStateLabel: receiptStateLabel,
      detailLineLabelColor: OnyxColorTokens.textMuted,
      detailLineValueColor: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent =>
          OnyxColorTokens.textPrimary,
        OnyxCameraBridgeHealthPanelVariant.admin =>
          OnyxColorTokens.textPrimary,
      },
      detailLineBottomPadding: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 6,
        OnyxCameraBridgeHealthPanelVariant.admin => 8,
      },
      detailTextColor: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent =>
          OnyxColorTokens.textSecondary,
        OnyxCameraBridgeHealthPanelVariant.admin =>
          OnyxColorTokens.textSecondary,
      },
      detailTextFontSize: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 10.9,
        OnyxCameraBridgeHealthPanelVariant.admin => 11.2,
      },
      badgeFontSize: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 11.4,
        OnyxCameraBridgeHealthPanelVariant.admin => 11.6,
      },
      badgeLetterSpacing: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 0.4,
        OnyxCameraBridgeHealthPanelVariant.admin => 0.35,
      },
      loadingTextHeight: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent => 1.35,
        OnyxCameraBridgeHealthPanelVariant.admin => null,
      },
      loadingVariant: switch (variant) {
        OnyxCameraBridgeHealthPanelVariant.agent =>
          OnyxAgentCameraBridgeHealthLoadingVariant.agent,
        OnyxCameraBridgeHealthPanelVariant.admin =>
          OnyxAgentCameraBridgeHealthLoadingVariant.admin,
      },
    );
  }
}
