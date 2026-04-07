import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum OnyxCameraBridgeActionButtonVariant { filled, outlined }

class OnyxCameraBridgeActionButton extends StatelessWidget {
  final Key? buttonKey;
  final OnyxCameraBridgeActionButtonVariant variant;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double letterSpacing;
  final double? borderRadius;

  const OnyxCameraBridgeActionButton({
    super.key,
    this.buttonKey,
    required this.variant,
    required this.onPressed,
    required this.busy,
    required this.icon,
    required this.label,
    required this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    required this.padding,
    required this.fontSize,
    this.letterSpacing = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius!),
          );
    final iconWidget = busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 16);
    final labelWidget = Text(
      label,
      style: GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: letterSpacing,
      ),
    );

    final child = switch (variant) {
      OnyxCameraBridgeActionButtonVariant.filled => FilledButton.tonalIcon(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: padding,
          shape: shape,
        ),
        icon: iconWidget,
        label: labelWidget,
      ),
      OnyxCameraBridgeActionButtonVariant.outlined => OutlinedButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: borderColor == null
              ? null
              : BorderSide(color: borderColor!.withValues(alpha: 0.58)),
          backgroundColor: const Color(0xFFF8FBFF),
          padding: padding,
          shape: shape,
        ),
        icon: iconWidget,
        label: labelWidget,
      ),
    };

    return SizedBox(width: double.infinity, child: child);
  }
}
