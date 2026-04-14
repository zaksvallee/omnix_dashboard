import 'package:flutter/material.dart';

/// Dashboard foundation tokens.
///
/// Base palette values were updated from the exact Figma design values supplied
/// on 2026-04-07. Remaining derived surfaces and semantic tokens are kept in
/// sync from that foundation.

class OnyxStatusColorSet {
  final Color foreground;
  final Color surface;
  final Color banner;
  final Color border;
  final String meaning;

  const OnyxStatusColorSet({
    required this.foreground,
    required this.surface,
    required this.banner,
    required this.border,
    required this.meaning,
  });
}

abstract final class OnyxColorTokens {
  static const Color shell = Color(0xFF0D0D14);
  static const Color backgroundPrimary = Color(0xFF0D0D14);
  static const Color backgroundSecondary = Color(0xFF13131E);
  static const Color card = Color(0xFF13131E);
  static const Color surface = Color(0xFF13131E);
  static const Color surfaceCard = Color(0xFF0D0D14);
  static const Color surfaceElevated = Color(0xFF1A1A2E);
  static const Color surfaceInset = Color(0xFF1A1A2E);
  static const Color surfaceEmphasis = Color(0xFF1A1A2E);

  static const Color borderSubtle = Color(0x269D4BFF);
  static const Color borderStrong = Color(0x669D4BFF);
  static const Color divider = Color(0x12FFFFFF);

  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textSecondary = Color(0x80FFFFFF);
  static const Color textMuted = Color(0x4DFFFFFF);
  static const Color textDisabled = Color(0x33FFFFFF);

  static const Color accentRed = Color(0xFFFF3B5C);
  static const Color accentGreen = Color(0xFF00D4AA);
  static const Color accentAmber = Color(0xFFF5A623);
  static const Color accentCyan = Color(0xFF9D4BFF);       // PRIMARY ACCENT — ONYX brand purple
  static const Color accentSky = Color(0xFF8FD1FF);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentBlue = Color(0xFF2A5D95);
  static const Color accentCyanTrue = Color(0xFF06B6D4); // Real cyan — distinct from accentCyan (brand purple)
  static const Color accentGreenTrue = Color(0xFF22C55E); // Spec green-500

  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusCritical = Color(0xFFEF4444);
  static const Color statusInfo = Color(0xFF3B82F6);

  static const Color glassSurface = Color(0x1AFFFFFF);
  static const Color glassHighlight = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x26FFFFFF);

  static const Color redSurface = Color(0xFF341516);
  static const Color greenSurface = Color(0xFF11211E);
  static const Color amberSurface = Color(0xFF342216);
  static const Color cyanSurface = Color(0x1A9D4BFF);
  static const Color purpleSurface = Color(0x1A9D4BFF);

  static const Color redBanner = Color(0xFF5E1C19);
  static const Color greenBanner = Color(0xFF183E31);
  static const Color amberBanner = Color(0xFF57290D);
  static const Color adminBanner = Color(0xFF471677);

  static const Color redBorder = Color(0xFF7F302E);
  static const Color greenBorder = Color(0xFF285546);
  static const Color amberBorder = Color(0xFF72501E);
  static const Color cyanBorder = Color(0x4D9D4BFF);
  static const Color purpleBorder = Color(0x669D4BFF);

  static const Color brand = Color(0xFF9D4BFF);
  static const Color brandDark = Color(0xFF7B2FBE);
}

abstract final class OnyxTypographyTokens {
  static const String sansFamily = 'Inter';

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w600;
  static const FontWeight extrabold = FontWeight.w700;

  static const double displayXl = 40;
  static const double displayLg = 32;
  static const double headlineLg = 28;
  static const double headlineMd = 24;
  static const double titleLg = 20;
  static const double titleMd = 18;
  static const double titleSm = 16;
  static const double bodyLg = 15;
  static const double bodyMd = 14;
  static const double bodySm = 13;
  static const double labelLg = 12;
  static const double labelMd = 11;
  static const double labelSm = 10;
  static const double metricLg = 56;
  static const double metricMd = 40;
  static const double metricSm = 28;

  static const double trackingDisplay = -1.0;
  static const double trackingHeadline = -0.5;
  static const double trackingTitle = -0.2;
  static const double trackingBody = 0.0;
  static const double trackingLabel = 0.25;
  static const double trackingCaps = 0.9;
}

abstract final class OnyxSpacingTokens {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double jumbo = 48;
  static const double hero = 64;

  static const double pageGutter = 24;
  static const double sectionGap = 24;
  static const double cardGap = 16;
  static const double cardPadding = 20;
  static const double cardPaddingDense = 16;
  static const double panelPadding = 24;
  static const double chipGap = 8;
  static const double railGap = 20;
  static const double topBarHeight = 48;
  static const double navRailWidth = 56;
  static const double buttonHeight = 44;
  static const double buttonHeightLarge = 48;
  static const double fieldHeight = 48;
}

abstract final class OnyxInsetsTokens {
  static const EdgeInsets page = EdgeInsets.all(OnyxSpacingTokens.pageGutter);
  static const EdgeInsets panel = EdgeInsets.all(
    OnyxSpacingTokens.panelPadding,
  );
  static const EdgeInsets card = EdgeInsets.all(OnyxSpacingTokens.cardPadding);
  static const EdgeInsets cardDense = EdgeInsets.all(
    OnyxSpacingTokens.cardPaddingDense,
  );
  static const EdgeInsets chip = EdgeInsets.symmetric(
    horizontal: OnyxSpacingTokens.sm,
    vertical: OnyxSpacingTokens.xs,
  );
  static const EdgeInsets field = EdgeInsets.symmetric(
    horizontal: OnyxSpacingTokens.md,
    vertical: OnyxSpacingTokens.sm,
  );
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: OnyxSpacingTokens.lg,
    vertical: OnyxSpacingTokens.sm,
  );
}

abstract final class OnyxRadiusTokens {
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double panel = 24;
  static const double pill = 999;

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusPanel = BorderRadius.all(
    Radius.circular(panel),
  );
  static const BorderRadius radiusPill = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class OnyxStatusTokens {
  /// Healthy, verified, secure, available, on-duty, or low-threat states.
  static const OnyxStatusColorSet nominal = OnyxStatusColorSet(
    foreground: OnyxColorTokens.accentGreen,
    surface: OnyxColorTokens.greenSurface,
    banner: OnyxColorTokens.greenBanner,
    border: OnyxColorTokens.greenBorder,
    meaning: 'Healthy, verified, secure, available, on-duty, or low threat.',
  );

  /// Elevated risk, pending review, degraded state, or at-risk posture.
  static const OnyxStatusColorSet warning = OnyxStatusColorSet(
    foreground: OnyxColorTokens.accentAmber,
    surface: OnyxColorTokens.amberSurface,
    banner: OnyxColorTokens.amberBanner,
    border: OnyxColorTokens.amberBorder,
    meaning: 'Pending review, degraded, at-risk, or warning-level state.',
  );

  /// Active alarm, urgent incident, blocked workflow, or critical operator task.
  static const OnyxStatusColorSet critical = OnyxStatusColorSet(
    foreground: OnyxColorTokens.accentRed,
    surface: OnyxColorTokens.redSurface,
    banner: OnyxColorTokens.redBanner,
    border: OnyxColorTokens.redBorder,
    meaning:
        'Critical, urgent, alarmed, blocked, or immediate operator action required.',
  );

  /// Actionable but non-severity color for navigation, selection, and controls.
  static const OnyxStatusColorSet interactive = OnyxStatusColorSet(
    foreground: OnyxColorTokens.accentCyan,
    surface: OnyxColorTokens.cyanSurface,
    banner: OnyxColorTokens.cyanSurface,
    border: OnyxColorTokens.cyanBorder,
    meaning:
        'Interactive, selected, actionable, or informational control state (purple brand accent).',
  );

  /// Administrative, reporting, governance, and configuration context.
  static const OnyxStatusColorSet admin = OnyxStatusColorSet(
    foreground: OnyxColorTokens.accentPurple,
    surface: OnyxColorTokens.purpleSurface,
    banner: OnyxColorTokens.adminBanner,
    border: OnyxColorTokens.purpleBorder,
    meaning: 'Administrative, governance, reporting, or configuration context.',
  );
}

/// High-level aliases for applying the token system in feature code.
abstract final class OnyxDesignTokens {
  static const Color backgroundPrimary = OnyxColorTokens.backgroundPrimary;
  static const Color backgroundSecondary = OnyxColorTokens.backgroundSecondary;
  static const Color cardSurface = OnyxColorTokens.card;
  static const Color surfaceCard = OnyxColorTokens.surfaceCard;
  static const Color surfaceElevated = OnyxColorTokens.surfaceElevated;
  static const Color surfaceInset = OnyxColorTokens.surfaceInset;
  static const Color borderSubtle = OnyxColorTokens.borderSubtle;
  static const Color borderStrong = OnyxColorTokens.borderStrong;
  static const Color divider = OnyxColorTokens.divider;

  static const Color textPrimary = OnyxColorTokens.textPrimary;
  static const Color textSecondary = OnyxColorTokens.textSecondary;
  static const Color textMuted = OnyxColorTokens.textMuted;

  static const Color redCritical = OnyxColorTokens.accentRed;
  static const Color greenNominal = OnyxColorTokens.accentGreen;
  static const Color amberWarning = OnyxColorTokens.accentAmber;
  static const Color purpleAdmin = OnyxColorTokens.accentPurple;
  static const Color accentPurple = OnyxColorTokens.accentPurple;
  static const Color accentTeal = OnyxColorTokens.accentTeal;
  static const Color cyanInteractive = OnyxColorTokens.accentCyan;
  static const Color accentSky = OnyxColorTokens.accentSky;
  static const Color accentBlue = OnyxColorTokens.accentBlue;
  static const Color cyanInfo = OnyxColorTokens.accentCyanTrue;   // #06B6D4
  static const Color greenSpec = OnyxColorTokens.accentGreenTrue; // #22C55E

  static const Color statusSuccess = OnyxColorTokens.statusSuccess;
  static const Color statusWarning = OnyxColorTokens.statusWarning;
  static const Color statusCritical = OnyxColorTokens.statusCritical;
  static const Color statusInfo = OnyxColorTokens.statusInfo;

  static const Color glassSurface = OnyxColorTokens.glassSurface;
  static const Color glassHighlight = OnyxColorTokens.glassHighlight;
  static const Color glassBorder = OnyxColorTokens.glassBorder;

  static const Color redSurface = OnyxColorTokens.redSurface;
  static const Color greenSurface = OnyxColorTokens.greenSurface;
  static const Color amberSurface = OnyxColorTokens.amberSurface;
  static const Color cyanSurface = OnyxColorTokens.cyanSurface;
  static const Color purpleSurface = OnyxColorTokens.purpleSurface;

  static const Color redBorder = OnyxColorTokens.redBorder;
  static const Color greenBorder = OnyxColorTokens.greenBorder;
  static const Color amberBorder = OnyxColorTokens.amberBorder;
  static const Color cyanBorder = OnyxColorTokens.cyanBorder;
  static const Color purpleBorder = OnyxColorTokens.purpleBorder;

  static const Color brand = OnyxColorTokens.brand;
  static const Color brandDark = OnyxColorTokens.brandDark;

  static const String fontFamily = OnyxTypographyTokens.sansFamily;
}
