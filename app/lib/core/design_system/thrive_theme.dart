import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

abstract final class ThriveTheme {
  static ThemeData build({required AppLogger logger}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ThriveColors.forest,
      primary: ThriveColors.forest,
      secondary: ThriveColors.mint,
      surface: Colors.white,
      error: ThriveColors.danger,
      onPrimary: Colors.white,
      onSecondary: ThriveColors.midnight,
      onSurface: ThriveColors.ink,
    );

    logger.info(
      code: 'theme_loaded',
      message: 'Design tokens loaded on app start',
      metadata: <String, Object?>{
        'seedColor': ThriveColors.forest.toARGB32(),
        'titleFontFamily': ThriveTypography.titleFontFamily,
        'bodyFontFamily': ThriveTypography.bodyFontFamily,
      },
    );

    final heading = GoogleFonts.acme(textStyle: ThriveTypography.headingBase);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ThriveColors.cloud,
      textTheme: TextTheme(
        headlineLarge: heading.copyWith(fontSize: 32),
        headlineMedium: heading.copyWith(fontSize: 30),
        headlineSmall: heading,
        bodyMedium: ThriveTypography.body,
        labelLarge: ThriveTypography.label,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ThriveColors.forest,
          foregroundColor: Colors.white,
          textStyle: ThriveTypography.label,
          shape: const RoundedRectangleBorder(
            borderRadius: ThriveRadius.button,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: ThriveSpacing.lg,
            vertical: ThriveSpacing.md,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: ThriveRadius.card),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ThriveColors.midnight,
        elevation: 0,
        titleTextStyle: heading.copyWith(fontSize: 22),
      ),
    );
  }
}
