import 'package:flutter/material.dart';

import 'onyx_camera_bridge_action_button.dart';

class OnyxCameraBridgeActionStack extends StatelessWidget {
  final Key validateButtonKey;
  final VoidCallback? onValidate;
  final bool validateBusy;
  final String validateLabel;
  final Key clearButtonKey;
  final bool showClearAction;
  final VoidCallback? onClear;
  final bool clearBusy;
  final String clearLabel;
  final Key copyButtonKey;
  final VoidCallback? onCopy;
  final String copyLabel;
  final Color primaryColor;
  final Color primaryBackgroundColor;
  final Color clearForegroundColor;
  final Color clearBorderColor;
  final Color copyForegroundColor;
  final Color copyBorderColor;
  final EdgeInsetsGeometry buttonPadding;
  final double fontSize;
  final double borderRadius;
  final double spacing;
  final double? letterSpacing;

  const OnyxCameraBridgeActionStack({
    super.key,
    required this.validateButtonKey,
    required this.onValidate,
    required this.validateBusy,
    required this.validateLabel,
    required this.clearButtonKey,
    required this.showClearAction,
    required this.onClear,
    required this.clearBusy,
    required this.clearLabel,
    required this.copyButtonKey,
    required this.onCopy,
    required this.copyLabel,
    required this.primaryColor,
    required this.primaryBackgroundColor,
    required this.clearForegroundColor,
    required this.clearBorderColor,
    required this.copyForegroundColor,
    required this.copyBorderColor,
    required this.buttonPadding,
    required this.fontSize,
    required this.borderRadius,
    required this.spacing,
    this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnyxCameraBridgeActionButton(
          buttonKey: validateButtonKey,
          variant: OnyxCameraBridgeActionButtonVariant.filled,
          onPressed: onValidate,
          busy: validateBusy,
          icon: Icons.health_and_safety_rounded,
          label: validateLabel,
          foregroundColor: primaryColor,
          backgroundColor: primaryBackgroundColor,
          padding: buttonPadding,
          fontSize: fontSize,
          borderRadius: borderRadius,
          letterSpacing: letterSpacing ?? 0,
        ),
        if (showClearAction) ...[
          SizedBox(height: spacing),
          OnyxCameraBridgeActionButton(
            buttonKey: clearButtonKey,
            variant: OnyxCameraBridgeActionButtonVariant.outlined,
            onPressed: onClear,
            busy: clearBusy,
            icon: Icons.history_toggle_off_rounded,
            label: clearLabel,
            foregroundColor: clearForegroundColor,
            borderColor: clearBorderColor,
            padding: buttonPadding,
            fontSize: fontSize,
            borderRadius: borderRadius,
            letterSpacing: letterSpacing ?? 0,
          ),
        ],
        SizedBox(height: spacing),
        OnyxCameraBridgeActionButton(
          buttonKey: copyButtonKey,
          variant: OnyxCameraBridgeActionButtonVariant.outlined,
          onPressed: onCopy,
          busy: false,
          icon: Icons.content_copy_rounded,
          label: copyLabel,
          foregroundColor: copyForegroundColor,
          borderColor: copyBorderColor,
          padding: buttonPadding,
          fontSize: fontSize,
          borderRadius: borderRadius,
          letterSpacing: letterSpacing ?? 0,
        ),
      ],
    );
  }
}
