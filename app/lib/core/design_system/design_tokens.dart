import 'package:flutter/material.dart';

abstract final class ThriveColors {
  static const Color forest = Color(0xFF0B6B4E);
  static const Color mint = Color(0xFF42C59E);
  static const Color midnight = Color(0xFF11243D);
  static const Color cloud = Color(0xFFF3F6F8);
  static const Color ink = Color(0xFF1F2A36);
  static const Color danger = Color(0xFFB3261E);
  static const Color success = Color(0xFF2E9D49);
  static const Color warning = Color(0xFFE68A00);
}

abstract final class ThriveSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class ThriveRadius {
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius button = BorderRadius.all(Radius.circular(12));
}

abstract final class ThriveTypography {
  static const String titleFontFamily = 'Acme';
  static const String bodyFontFamily = 'Roboto';

  static const TextStyle headingBase = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: ThriveColors.midnight,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: ThriveColors.ink,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
