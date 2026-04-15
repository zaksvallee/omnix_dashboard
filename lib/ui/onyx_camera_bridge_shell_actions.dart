import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import 'theme/onyx_design_tokens.dart';
import 'onyx_camera_bridge_action_stack.dart';

enum OnyxCameraBridgeShellActionsVariant { agent, admin }

class OnyxCameraBridgeShellActions extends StatelessWidget {
  final Key validateButtonKey;
  final VoidCallback? onValidate;
  final bool validateBusy;
  final OnyxAgentCameraBridgeReceiptState? receiptState;
  final Key clearButtonKey;
  final bool showClearAction;
  final VoidCallback? onClear;
  final bool clearBusy;
  final Key copyButtonKey;
  final VoidCallback? onCopy;
  final Color accent;
  final OnyxCameraBridgeShellActionsVariant variant;

  const OnyxCameraBridgeShellActions({
    super.key,
    required this.validateButtonKey,
    required this.onValidate,
    required this.validateBusy,
    required this.receiptState,
    required this.clearButtonKey,
    required this.showClearAction,
    required this.onClear,
    required this.clearBusy,
    required this.copyButtonKey,
    required this.onCopy,
    required this.accent,
    this.variant = OnyxCameraBridgeShellActionsVariant.agent,
  });

  @override
  Widget build(BuildContext context) {
    final labelVariant = switch (variant) {
      OnyxCameraBridgeShellActionsVariant.agent =>
        OnyxAgentCameraBridgeValidateActionLabelVariant.agent,
      OnyxCameraBridgeShellActionsVariant.admin =>
        OnyxAgentCameraBridgeValidateActionLabelVariant.admin,
    };
    final clearLabelVariant = switch (variant) {
      OnyxCameraBridgeShellActionsVariant.agent =>
        OnyxAgentCameraBridgeClearActionLabelVariant.agent,
      OnyxCameraBridgeShellActionsVariant.admin =>
        OnyxAgentCameraBridgeClearActionLabelVariant.admin,
    };
    final copyLabelVariant = switch (variant) {
      OnyxCameraBridgeShellActionsVariant.agent =>
        OnyxAgentCameraBridgeCopyActionLabelVariant.agent,
      OnyxCameraBridgeShellActionsVariant.admin =>
        OnyxAgentCameraBridgeCopyActionLabelVariant.admin,
    };
    return OnyxCameraBridgeActionStack(
      validateButtonKey: validateButtonKey,
      onValidate: onValidate,
      validateBusy: validateBusy,
      validateLabel: describeOnyxAgentCameraBridgeValidateActionLabel(
        action: resolveOnyxAgentCameraBridgeValidateAction(
          receiptState: receiptState,
          validationInFlight: validateBusy,
        ),
        variant: labelVariant,
      ),
      clearButtonKey: clearButtonKey,
      showClearAction: showClearAction,
      onClear: onClear,
      clearBusy: clearBusy,
      clearLabel: describeOnyxAgentCameraBridgeClearActionLabel(
        resetInFlight: clearBusy,
        variant: clearLabelVariant,
      ),
      copyButtonKey: copyButtonKey,
      onCopy: onCopy,
      copyLabel: describeOnyxAgentCameraBridgeCopyActionLabel(
        variant: copyLabelVariant,
      ),
      primaryColor: accent,
      primaryBackgroundColor: accent.withValues(alpha: 0.14),
      clearForegroundColor: OnyxColorTokens.accentRed,
      clearBorderColor: OnyxColorTokens.redBorder,
      copyForegroundColor: accent,
      copyBorderColor: accent.withValues(
        alpha: switch (variant) {
          OnyxCameraBridgeShellActionsVariant.agent => 0.45,
          OnyxCameraBridgeShellActionsVariant.admin => 0.4,
        },
      ),
      buttonPadding: switch (variant) {
        OnyxCameraBridgeShellActionsVariant.agent => const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        OnyxCameraBridgeShellActionsVariant.admin => const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      },
      fontSize: switch (variant) {
        OnyxCameraBridgeShellActionsVariant.agent => 11.4,
        OnyxCameraBridgeShellActionsVariant.admin => 11.8,
      },
      borderRadius: 10,
      spacing: switch (variant) {
        OnyxCameraBridgeShellActionsVariant.agent => 8,
        OnyxCameraBridgeShellActionsVariant.admin => 10,
      },
      letterSpacing: switch (variant) {
        OnyxCameraBridgeShellActionsVariant.agent => null,
        OnyxCameraBridgeShellActionsVariant.admin => 0.25,
      },
    );
  }
}
