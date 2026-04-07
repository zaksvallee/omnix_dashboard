import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'onyx_camera_bridge_chip_wrap.dart';
import 'onyx_camera_bridge_status_badge.dart';
import 'onyx_camera_bridge_tone_resolver.dart';

enum OnyxCameraBridgeChipListVariant { agent, admin }

class OnyxCameraBridgeChipList extends StatelessWidget {
  final Widget? leading;
  final List<OnyxAgentCameraBridgeChip> chips;
  final Color statusAccent;
  final OnyxCameraBridgeChipListVariant variant;
  final double spacing;
  final double runSpacing;

  const OnyxCameraBridgeChipList({
    super.key,
    this.leading,
    required this.chips,
    required this.statusAccent,
    this.variant = OnyxCameraBridgeChipListVariant.agent,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeChipWrap(
      leading: leading,
      spacing: spacing,
      runSpacing: runSpacing,
      chips: [
        for (final chip in chips)
          Builder(
            builder: (context) {
              final accent = resolveOnyxCameraBridgeChipColorForStatusAccent(
                chip.tone,
                statusAccent: statusAccent,
              );
              return OnyxCameraBridgeStatusBadge(
                label: chip.label,
                foregroundColor: accent,
                backgroundColor: switch (variant) {
                  OnyxCameraBridgeChipListVariant.agent => null,
                  OnyxCameraBridgeChipListVariant.admin => accent.withValues(
                    alpha: 0.12,
                  ),
                },
                borderColor: accent.withValues(
                  alpha: switch (variant) {
                    OnyxCameraBridgeChipListVariant.agent => 0.45,
                    OnyxCameraBridgeChipListVariant.admin => 0.35,
                  },
                ),
                padding: switch (variant) {
                  OnyxCameraBridgeChipListVariant.agent =>
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  OnyxCameraBridgeChipListVariant.admin =>
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                },
                fontSize: switch (variant) {
                  OnyxCameraBridgeChipListVariant.agent => 9.8,
                  OnyxCameraBridgeChipListVariant.admin => 9,
                },
              );
            },
          ),
      ],
    );
  }
}
