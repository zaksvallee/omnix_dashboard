import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onyx_design_tokens.dart';

abstract final class OnyxTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: OnyxColorTokens.accentCyan,
      onPrimary: OnyxColorTokens.textPrimary,
      secondary: OnyxColorTokens.accentPurple,
      onSecondary: OnyxColorTokens.textPrimary,
      tertiary: OnyxColorTokens.accentGreen,
      onTertiary: OnyxColorTokens.textPrimary,
      error: OnyxColorTokens.accentRed,
      onError: OnyxColorTokens.textPrimary,
      surface: OnyxColorTokens.card,
      onSurface: OnyxColorTokens.textPrimary,
      primaryContainer: OnyxColorTokens.cyanSurface,
      secondaryContainer: OnyxColorTokens.purpleSurface,
      tertiaryContainer: OnyxColorTokens.greenSurface,
      errorContainer: OnyxColorTokens.redSurface,
      outline: OnyxColorTokens.borderSubtle,
      outlineVariant: OnyxColorTokens.divider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: OnyxColorTokens.textPrimary,
      onInverseSurface: OnyxColorTokens.shell,
      inversePrimary: OnyxColorTokens.accentCyan,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.displayXl,
        fontWeight: OnyxTypographyTokens.extrabold,
        letterSpacing: OnyxTypographyTokens.trackingDisplay,
        color: OnyxColorTokens.textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.displayLg,
        fontWeight: OnyxTypographyTokens.extrabold,
        letterSpacing: OnyxTypographyTokens.trackingDisplay,
        color: OnyxColorTokens.textPrimary,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.headlineLg,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingHeadline,
        color: OnyxColorTokens.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.headlineMd,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingHeadline,
        color: OnyxColorTokens.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.titleLg,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingTitle,
        color: OnyxColorTokens.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.titleMd,
        fontWeight: OnyxTypographyTokens.semibold,
        letterSpacing: OnyxTypographyTokens.trackingTitle,
        color: OnyxColorTokens.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.titleSm,
        fontWeight: OnyxTypographyTokens.semibold,
        letterSpacing: OnyxTypographyTokens.trackingBody,
        color: OnyxColorTokens.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.bodyLg,
        fontWeight: OnyxTypographyTokens.medium,
        letterSpacing: OnyxTypographyTokens.trackingBody,
        color: OnyxColorTokens.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.bodyMd,
        fontWeight: OnyxTypographyTokens.medium,
        letterSpacing: OnyxTypographyTokens.trackingBody,
        color: OnyxColorTokens.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.bodySm,
        fontWeight: OnyxTypographyTokens.medium,
        letterSpacing: OnyxTypographyTokens.trackingBody,
        color: OnyxColorTokens.textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.labelLg,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingLabel,
        color: OnyxColorTokens.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.labelMd,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingLabel,
        color: OnyxColorTokens.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: OnyxTypographyTokens.labelSm,
        fontWeight: OnyxTypographyTokens.bold,
        letterSpacing: OnyxTypographyTokens.trackingCaps,
        color: OnyxColorTokens.textMuted,
      ),
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: OnyxRadiusTokens.radiusLg,
      borderSide: const BorderSide(color: OnyxColorTokens.borderSubtle),
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: OnyxColorTokens.backgroundPrimary,
      canvasColor: OnyxColorTokens.backgroundSecondary,
      cardColor: OnyxColorTokens.card,
      dividerColor: OnyxColorTokens.divider,
      splashColor: OnyxColorTokens.accentCyan.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      hoverColor: OnyxColorTokens.accentCyan.withValues(alpha: 0.08),
      focusColor: OnyxColorTokens.accentCyan.withValues(alpha: 0.16),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: OnyxColorTokens.shell,
        foregroundColor: OnyxColorTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: OnyxSpacingTokens.topBarHeight,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: OnyxColorTokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: OnyxRadiusTokens.radiusXl,
          side: const BorderSide(color: OnyxColorTokens.borderSubtle),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OnyxColorTokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: OnyxRadiusTokens.radiusPanel,
          side: const BorderSide(color: OnyxColorTokens.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OnyxColorTokens.surfaceInset,
        contentPadding: OnyxInsetsTokens.field,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: OnyxColorTokens.textMuted,
        ),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: OnyxColorTokens.accentCyan),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: OnyxColorTokens.accentRed),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: OnyxColorTokens.accentRed),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: OnyxColorTokens.accentCyan,
          foregroundColor: Colors.white,
          disabledBackgroundColor: OnyxColorTokens.surface,
          disabledForegroundColor: OnyxColorTokens.textDisabled,
          minimumSize: const Size(0, OnyxSpacingTokens.buttonHeightLarge),
          padding: OnyxInsetsTokens.button,
          shape: RoundedRectangleBorder(
            borderRadius: OnyxRadiusTokens.radiusLg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: OnyxColorTokens.accentCyan,
          minimumSize: const Size(0, OnyxSpacingTokens.buttonHeight),
          padding: OnyxInsetsTokens.button,
          side: const BorderSide(color: OnyxColorTokens.cyanBorder),
          shape: RoundedRectangleBorder(
            borderRadius: OnyxRadiusTokens.radiusLg,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: OnyxColorTokens.accentCyan,
          padding: const EdgeInsets.symmetric(
            horizontal: OnyxSpacingTokens.md,
            vertical: OnyxSpacingTokens.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: OnyxRadiusTokens.radiusMd,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: OnyxColorTokens.surface,
        disabledColor: OnyxColorTokens.surfaceInset,
        selectedColor: OnyxColorTokens.cyanSurface,
        secondarySelectedColor: OnyxColorTokens.cyanSurface,
        side: const BorderSide(color: OnyxColorTokens.borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusMd),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: OnyxColorTokens.accentCyan,
        ),
        padding: OnyxInsetsTokens.chip,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: OnyxColorTokens.surface,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: OnyxColorTokens.accentCyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: OnyxRadiusTokens.radiusLg,
          side: const BorderSide(color: OnyxColorTokens.borderSubtle),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: OnyxColorTokens.textSecondary,
        textColor: OnyxColorTokens.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: OnyxRadiusTokens.radiusLg),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: OnyxColorTokens.divider,
        indicatorColor: OnyxColorTokens.accentCyan,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: OnyxColorTokens.accentCyan,
        unselectedLabelColor: OnyxColorTokens.textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          color: OnyxColorTokens.textSecondary,
        ),
      ),
      iconTheme: const IconThemeData(
        color: OnyxColorTokens.textSecondary,
        size: 20,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: OnyxColorTokens.shell,
        selectedIconTheme: const IconThemeData(
          color: OnyxColorTokens.accentCyan,
        ),
        unselectedIconTheme: const IconThemeData(
          color: OnyxColorTokens.textSecondary,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: OnyxColorTokens.accentCyan,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium,
        indicatorColor: OnyxColorTokens.cyanSurface,
      ),
    );
  }
}
