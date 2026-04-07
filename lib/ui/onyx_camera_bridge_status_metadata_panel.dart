import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_status_metadata_block.dart';

enum OnyxCameraBridgeStatusMetadataPanelVariant { agent, admin }

class OnyxCameraBridgeStatusMetadataPanel extends StatelessWidget {
  final OnyxAgentCameraBridgeStatus status;
  final OnyxCameraBridgeStatusMetadataPanelVariant variant;

  const OnyxCameraBridgeStatusMetadataPanel({
    super.key,
    required this.status,
    this.variant = OnyxCameraBridgeStatusMetadataPanelVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeStatusMetadataBlock(
      fields: status.visibleDetailFields(
        variant: switch (variant) {
          OnyxCameraBridgeStatusMetadataPanelVariant.agent =>
            OnyxAgentCameraBridgeStatusDetailVariant.agent,
          OnyxCameraBridgeStatusMetadataPanelVariant.admin =>
            OnyxAgentCameraBridgeStatusDetailVariant.admin,
        },
      ),
      labelColor: const Color(0xFF8EA4C2),
      valueColor: switch (variant) {
        OnyxCameraBridgeStatusMetadataPanelVariant.agent => const Color(
          0xFFDCE8F7,
        ),
        OnyxCameraBridgeStatusMetadataPanelVariant.admin => const Color(
          0xFFEAF4FF,
        ),
      },
      fieldBottomPadding: switch (variant) {
        OnyxCameraBridgeStatusMetadataPanelVariant.agent => 6,
        OnyxCameraBridgeStatusMetadataPanelVariant.admin => 8,
      },
      detail: status.detail,
      detailTopSpacing: switch (variant) {
        OnyxCameraBridgeStatusMetadataPanelVariant.agent => 8,
        OnyxCameraBridgeStatusMetadataPanelVariant.admin => 10,
      },
      detailStyle: GoogleFonts.inter(
        color: switch (variant) {
          OnyxCameraBridgeStatusMetadataPanelVariant.agent => const Color(
            0xFF7F93AD,
          ),
          OnyxCameraBridgeStatusMetadataPanelVariant.admin => const Color(
            0xFFDDE7F2,
          ),
        },
        fontSize: switch (variant) {
          OnyxCameraBridgeStatusMetadataPanelVariant.agent => 11.1,
          OnyxCameraBridgeStatusMetadataPanelVariant.admin => 11.5,
        },
        fontWeight: FontWeight.w600,
        height: switch (variant) {
          OnyxCameraBridgeStatusMetadataPanelVariant.agent => 1.4,
          OnyxCameraBridgeStatusMetadataPanelVariant.admin => 1.42,
        },
      ),
    );
  }
}
