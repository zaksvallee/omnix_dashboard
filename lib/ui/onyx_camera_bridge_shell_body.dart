import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';
import 'onyx_camera_bridge_chip_list.dart';
import 'onyx_camera_bridge_health_panel.dart';
import 'onyx_camera_bridge_shell_actions.dart';
import 'onyx_camera_bridge_status_metadata_panel.dart';
import 'onyx_camera_bridge_summary_panel.dart';
import 'onyx_camera_bridge_validation_panel.dart';

enum OnyxCameraBridgeShellBodyVariant { agent, admin }

class OnyxCameraBridgeShellBody extends StatelessWidget {
  final OnyxAgentCameraBridgeStatus status;
  final OnyxAgentCameraBridgeSurfaceState surfaceState;
  final OnyxAgentCameraBridgeHealthSnapshot? snapshot;
  final Color accent;
  final Color healthAccent;
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
  final Widget? chipLeading;
  final OnyxCameraBridgeShellBodyVariant variant;

  const OnyxCameraBridgeShellBody({
    super.key,
    required this.status,
    required this.surfaceState,
    required this.snapshot,
    required this.accent,
    required this.healthAccent,
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
    this.chipLeading,
    this.variant = OnyxCameraBridgeShellBodyVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    final chipVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxAgentCameraBridgeChipVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxAgentCameraBridgeChipVariant.admin,
    };
    final chipListVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeChipListVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeChipListVariant.admin,
    };
    final metadataVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeStatusMetadataPanelVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeStatusMetadataPanelVariant.admin,
    };
    final summaryVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeSummaryPanelVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeSummaryPanelVariant.admin,
    };
    final validationVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeValidationPanelVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeValidationPanelVariant.admin,
    };
    final healthVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeHealthPanelVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeHealthPanelVariant.admin,
    };
    final actionsVariant = switch (variant) {
      OnyxCameraBridgeShellBodyVariant.agent =>
        OnyxCameraBridgeShellActionsVariant.agent,
      OnyxCameraBridgeShellBodyVariant.admin =>
        OnyxCameraBridgeShellActionsVariant.admin,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnyxCameraBridgeChipList(
          leading: chipLeading,
          chips: visibleOnyxAgentCameraBridgePanelChips(
            authRequired: status.authRequired,
            bridgeLive: status.isLive,
            shellState: surfaceState.shellState,
            receiptState: surfaceState.receiptState,
            variant: chipVariant,
          ),
          statusAccent: accent,
          variant: chipListVariant,
        ),
        switch (variant) {
          OnyxCameraBridgeShellBodyVariant.agent => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              OnyxCameraBridgeSummaryPanel(
                panelKey: summaryPanelKey,
                summary: surfaceState.controllerCardSummary,
                accent: accent,
                variant: summaryVariant,
              ),
              OnyxCameraBridgeValidationPanel(
                runtimeState: surfaceState.runtimeState,
                variant: validationVariant,
              ),
              const SizedBox(height: 8),
              OnyxCameraBridgeStatusMetadataPanel(
                status: status,
                variant: metadataVariant,
              ),
              if (surfaceState.controls.showHealthCard) ...[
                const SizedBox(height: 10),
                OnyxCameraBridgeHealthPanel(
                  cardKey: healthCardKey,
                  snapshot: snapshot,
                  accent: healthAccent,
                  receiptStateLabel: surfaceState.receiptStateLabel,
                  variant: healthVariant,
                ),
              ],
              const SizedBox(height: 10),
              OnyxCameraBridgeShellActions(
                validateButtonKey: validateButtonKey,
                onValidate: surfaceState.controls.canValidate ? onValidate : null,
                validateBusy: validateBusy,
                receiptState: surfaceState.receiptState,
                clearButtonKey: clearButtonKey,
                showClearAction:
                    surfaceState.controls.showClearReceiptAction,
                onClear: surfaceState.controls.canClearReceipt ? onClear : null,
                clearBusy: clearBusy,
                copyButtonKey: copyButtonKey,
                onCopy: onCopy,
                accent: accent,
                variant: actionsVariant,
              ),
            ],
          ),
          OnyxCameraBridgeShellBodyVariant.admin => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              OnyxCameraBridgeStatusMetadataPanel(
                status: status,
                variant: metadataVariant,
              ),
              const SizedBox(height: 10),
              OnyxCameraBridgeSummaryPanel(
                panelKey: summaryPanelKey,
                summary: surfaceState.shellSummary,
                accent: accent,
                variant: summaryVariant,
              ),
              OnyxCameraBridgeValidationPanel(
                runtimeState: surfaceState.runtimeState,
                variant: validationVariant,
              ),
              const SizedBox(height: 10),
              if (surfaceState.controls.showHealthCard) ...[
                OnyxCameraBridgeHealthPanel(
                  cardKey: healthCardKey,
                  snapshot: snapshot,
                  accent: healthAccent,
                  receiptStateLabel: surfaceState.receiptStateLabel,
                  variant: healthVariant,
                ),
                const SizedBox(height: 10),
              ],
              OnyxCameraBridgeShellActions(
                validateButtonKey: validateButtonKey,
                onValidate: surfaceState.controls.canValidate ? onValidate : null,
                validateBusy: validateBusy,
                receiptState: surfaceState.receiptState,
                clearButtonKey: clearButtonKey,
                showClearAction:
                    surfaceState.controls.showClearReceiptAction,
                onClear: surfaceState.controls.canClearReceipt ? onClear : null,
                clearBusy: clearBusy,
                copyButtonKey: copyButtonKey,
                onCopy: onCopy,
                accent: accent,
                variant: actionsVariant,
              ),
            ],
          ),
        },
      ],
    );
  }
}
