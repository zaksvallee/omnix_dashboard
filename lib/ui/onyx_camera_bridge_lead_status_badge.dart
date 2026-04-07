import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_status_badge.dart';

enum OnyxCameraBridgeLeadStatusBadgeVariant { agent, admin }

class OnyxCameraBridgeLeadStatusBadge extends StatelessWidget {
  final OnyxAgentCameraBridgeStatus status;
  final Color accent;
  final OnyxCameraBridgeLeadStatusBadgeVariant variant;

  const OnyxCameraBridgeLeadStatusBadge({
    super.key,
    required this.status,
    required this.accent,
    this.variant = OnyxCameraBridgeLeadStatusBadgeVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBadge = visibleOnyxAgentCameraBridgeStatusBadgeForStatus(
      status,
    );
    return OnyxCameraBridgeStatusBadge(
      label: visibleBadge.label,
      foregroundColor: accent,
      backgroundColor: switch (variant) {
        OnyxCameraBridgeLeadStatusBadgeVariant.agent => null,
        OnyxCameraBridgeLeadStatusBadgeVariant.admin => accent.withValues(
          alpha: 0.15,
        ),
      },
      borderColor: accent.withValues(
        alpha: switch (variant) {
          OnyxCameraBridgeLeadStatusBadgeVariant.agent => 0.5,
          OnyxCameraBridgeLeadStatusBadgeVariant.admin => 0.45,
        },
      ),
      fontSize: switch (variant) {
        OnyxCameraBridgeLeadStatusBadgeVariant.agent => 9.8,
        OnyxCameraBridgeLeadStatusBadgeVariant.admin => 9,
      },
    );
  }
}
