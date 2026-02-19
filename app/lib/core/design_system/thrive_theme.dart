import 'package:flutter/material.dart';
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
        'fontFamily': ThriveTypography.primaryFontFamily,
      },
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ThriveColors.cloud,
      textTheme: const TextTheme(
        headlineSmall: ThriveTypography.heading,
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ThriveColors.midnight,
        elevation: 0,
      ),
    );
  }
}
