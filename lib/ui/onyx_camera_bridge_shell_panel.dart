import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'theme/onyx_design_tokens.dart';
import 'onyx_camera_bridge_lead_status_badge.dart';
import 'onyx_camera_bridge_shell_body.dart';
import 'onyx_camera_bridge_shell_surface.dart';
import 'onyx_camera_bridge_tone_resolver.dart';

enum OnyxCameraBridgeShellPanelVariant { agent, admin }

class OnyxCameraBridgeShellPanel extends StatelessWidget {
  final Key? cardKey;
  final OnyxAgentCameraBridgeStatus status;
  final OnyxAgentCameraBridgeSurfaceState surfaceState;
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final OnyxCameraBridgeSurfaceAccents accents;
  final Key? summaryPanelKey;
  final Key? healthCardKey;
  final Key validateButtonKey;
  final VoidCallback? onValidate;
  final bool validateBusy;
  final Key clearButtonKey;
  final VoidCallback? onClear;
  final bool clearBusy;
  final Key copyButtonKey;
  final VoidCallback? onCopy;
  final OnyxCameraBridgeShellPanelVariant variant;
  final Key? stagingIndicatorKey;
  final String? stagingIndicatorLabel;
  final String? stagingIndicatorDetail;

  const OnyxCameraBridgeShellPanel({
    super.key,
    this.cardKey,
    required this.status,
    required this.surfaceState,
    required this.snapshot,
    required this.accents,
    this.summaryPanelKey,
    this.healthCardKey,
    required this.validateButtonKey,
    required this.onValidate,
    required this.validateBusy,
    required this.clearButtonKey,
    required this.onClear,
    required this.clearBusy,
    required this.copyButtonKey,
    required this.onCopy,
    this.variant = OnyxCameraBridgeShellPanelVariant.agent,
    this.stagingIndicatorKey,
    this.stagingIndicatorLabel,
    this.stagingIndicatorDetail,
  });

  @override
  Widget build(BuildContext context) {
    return OnyxCameraBridgeShellSurface(
      cardKey: cardKey,
      accent: accents.status,
      variant: switch (variant) {
        OnyxCameraBridgeShellPanelVariant.agent =>
          OnyxCameraBridgeShellSurfaceVariant.agent,
        OnyxCameraBridgeShellPanelVariant.admin =>
          OnyxCameraBridgeShellSurfaceVariant.admin,
      },
      child: switch (variant) {
        OnyxCameraBridgeShellPanelVariant.agent => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showStagingIndicator) ...[
              _stagingIndicator(),
              const SizedBox(height: 12),
            ],
            OnyxCameraBridgeShellBody(
              status: status,
              surfaceState: surfaceState,
              snapshot: snapshot,
              accent: accents.status,
              healthAccent: accents.health,
              summaryPanelKey: summaryPanelKey,
              healthCardKey: healthCardKey,
              validateButtonKey: validateButtonKey,
              onValidate: onValidate,
              validateBusy: validateBusy,
              clearButtonKey: clearButtonKey,
              onClear: onClear,
              clearBusy: clearBusy,
              copyButtonKey: copyButtonKey,
              onCopy: onCopy,
              chipLeading: OnyxCameraBridgeLeadStatusBadge(
                status: status,
                accent: accents.status,
              ),
            ),
          ],
        ),
        OnyxCameraBridgeShellPanelVariant.admin => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOCAL CAMERA BRIDGE',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Embedded LAN listener for approved camera packets and health checks.',
                        style: GoogleFonts.inter(
                          color: OnyxColorTokens.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OnyxCameraBridgeLeadStatusBadge(
                  status: status,
                  accent: accents.status,
                  variant: OnyxCameraBridgeLeadStatusBadgeVariant.admin,
                ),
              ],
            ),
            if (_showStagingIndicator) ...[
              const SizedBox(height: 12),
              _stagingIndicator(),
            ],
            OnyxCameraBridgeShellBody(
              status: status,
              surfaceState: surfaceState,
              snapshot: snapshot,
              accent: accents.status,
              healthAccent: accents.health,
              summaryPanelKey: summaryPanelKey,
              healthCardKey: healthCardKey,
              validateButtonKey: validateButtonKey,
              onValidate: onValidate,
              validateBusy: validateBusy,
              clearButtonKey: clearButtonKey,
              onClear: onClear,
              clearBusy: clearBusy,
              copyButtonKey: copyButtonKey,
              onCopy: onCopy,
              variant: OnyxCameraBridgeShellBodyVariant.admin,
            ),
          ],
        ),
      },
    );
  }

  bool get _showStagingIndicator =>
      (stagingIndicatorLabel ?? '').trim().isNotEmpty;

  Widget _stagingIndicator() {
    return Container(
      key: stagingIndicatorKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OnyxColorTokens.purpleSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OnyxColorTokens.purpleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stagingIndicatorLabel!,
            style: GoogleFonts.inter(
              color: OnyxColorTokens.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
            ),
          ),
          if ((stagingIndicatorDetail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stagingIndicatorDetail!,
              style: GoogleFonts.inter(
                color: OnyxColorTokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
