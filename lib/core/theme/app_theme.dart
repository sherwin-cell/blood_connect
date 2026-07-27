import 'package:flutter/material.dart';

/// Shared colors and text styles used across every feature.
/// Anything used by more than one feature belongs here in core/,
/// not duplicated inside individual feature folders.
class AppColors {
  static const Color primaryRed = Color(0xFFB3261E);
  static const Color deepRed = Color(0xFF7A1815);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFF3D9D8);
}

class AppTextStyles {
  static const TextStyle appName = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textLight,
    letterSpacing: 0.5,
  );

  static const TextStyle tagline = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );
}
