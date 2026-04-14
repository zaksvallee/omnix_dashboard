import 'package:flutter/material.dart';
import 'package:omnix_dashboard/ui/theme/onyx_design_tokens.dart';

enum OnyxSeverity { critical, warning, info, success }

class OnyxStatusBanner extends StatelessWidget {
  final String message;
  final OnyxSeverity severity;
  final String? action;

  const OnyxStatusBanner({
    super.key,
    required this.message,
    required this.severity,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForSeverity(severity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          left: BorderSide(color: colors.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _iconForSeverity(severity),
            color: colors.accent,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            Text(
              action!,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconForSeverity(OnyxSeverity severity) => switch (severity) {
    OnyxSeverity.critical => Icons.error_outline,
    OnyxSeverity.warning => Icons.warning_amber_outlined,
    OnyxSeverity.info => Icons.info_outline,
    OnyxSeverity.success => Icons.check_circle_outline,
  };

  static _BannerColors _colorsForSeverity(OnyxSeverity severity) =>
      switch (severity) {
        OnyxSeverity.critical => const _BannerColors(
          accent: OnyxDesignTokens.statusCritical,
          background: OnyxColorTokens.redSurface,
          text: OnyxColorTokens.accentRed,
        ),
        OnyxSeverity.warning => const _BannerColors(
          accent: OnyxDesignTokens.statusWarning,
          background: OnyxColorTokens.amberSurface,
          text: OnyxColorTokens.accentAmber,
        ),
        OnyxSeverity.info => const _BannerColors(
          accent: OnyxDesignTokens.statusInfo,
          background: OnyxColorTokens.cyanSurface,
          text: OnyxColorTokens.accentSky,
        ),
        OnyxSeverity.success => const _BannerColors(
          accent: OnyxDesignTokens.statusSuccess,
          background: OnyxColorTokens.greenSurface,
          text: OnyxColorTokens.accentGreen,
        ),
      };
}

class _BannerColors {
  final Color accent;
  final Color background;
  final Color text;
  const _BannerColors({
    required this.accent,
    required this.background,
    required this.text,
  });
}
