import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'onyx_camera_bridge_tone_resolver.dart';
import 'onyx_camera_bridge_validation_summary.dart';

enum OnyxCameraBridgeValidationPanelVariant { agent, admin }

class OnyxCameraBridgeValidationPanel extends StatelessWidget {
  final OnyxAgentCameraBridgeRuntimeState runtimeState;
  final OnyxCameraBridgeValidationPanelVariant variant;

  const OnyxCameraBridgeValidationPanel({
    super.key,
    required this.runtimeState,
    this.variant = OnyxCameraBridgeValidationPanelVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeValidationSummary(
      summary: runtimeState.validationSummary,
      color: resolveOnyxCameraBridgeValidationColorForSurface(
        runtimeState.validationTone ??
            OnyxAgentCameraBridgeValidationTone.neutral,
        variant: switch (variant) {
          OnyxCameraBridgeValidationPanelVariant.agent =>
            OnyxCameraBridgeSurfaceToneVariant.agent,
          OnyxCameraBridgeValidationPanelVariant.admin =>
            OnyxCameraBridgeSurfaceToneVariant.admin,
        },
      ),
      topSpacing: switch (variant) {
        OnyxCameraBridgeValidationPanelVariant.agent => 8,
        OnyxCameraBridgeValidationPanelVariant.admin => 10,
      },
      fontSize: switch (variant) {
        OnyxCameraBridgeValidationPanelVariant.agent => 10.9,
        OnyxCameraBridgeValidationPanelVariant.admin => 11.0,
      },
      height: switch (variant) {
        OnyxCameraBridgeValidationPanelVariant.agent => 1.35,
        OnyxCameraBridgeValidationPanelVariant.admin => 1.4,
      },
    );
  }
}
