import 'package:flutter/material.dart';

import 'onyx_camera_bridge_shell_card.dart';
import 'theme/onyx_design_tokens.dart';

enum OnyxCameraBridgeShellSurfaceVariant { agent, admin }

class OnyxCameraBridgeShellSurface extends StatelessWidget {
  final Key? cardKey;
  final Color accent;
  final OnyxCameraBridgeShellSurfaceVariant variant;
  final Widget child;

  const OnyxCameraBridgeShellSurface({
    super.key,
    this.cardKey,
    required this.accent,
    this.variant = OnyxCameraBridgeShellSurfaceVariant.agent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeShellCard(
      cardKey: cardKey,
      padding: switch (variant) {
        OnyxCameraBridgeShellSurfaceVariant.agent => const EdgeInsets.all(10),
        OnyxCameraBridgeShellSurfaceVariant.admin => const EdgeInsets.all(18),
      },
      backgroundColor: switch (variant) {
        OnyxCameraBridgeShellSurfaceVariant.agent =>
          OnyxColorTokens.surfaceElevated,
        OnyxCameraBridgeShellSurfaceVariant.admin =>
          OnyxColorTokens.backgroundSecondary,
      },
      borderRadius: switch (variant) {
        OnyxCameraBridgeShellSurfaceVariant.agent => 12,
        OnyxCameraBridgeShellSurfaceVariant.admin => 16,
      },
      borderColor: switch (variant) {
        OnyxCameraBridgeShellSurfaceVariant.agent => accent.withValues(
          alpha: 0.28,
        ),
        OnyxCameraBridgeShellSurfaceVariant.admin => OnyxColorTokens.divider,
      },
      child: child,
    );
  }
}
