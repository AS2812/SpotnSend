import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTypography {
  static TextStyle get headingLarge => GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.black,
      );

  static TextStyle get headingMedium => GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      );

  static TextStyle get headingSmall => GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get bodyLarge => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.grey,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.grey,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.grey,
      );

  static TextStyle get number => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.black,
      );

  static TextTheme buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.white : AppColors.black;
    final secondaryColor = isDark ? AppColors.white.withOpacity(0.7) : AppColors.grey;

    return TextTheme(
      displayLarge: headingLarge.copyWith(color: baseColor),
      displayMedium: headingMedium.copyWith(color: baseColor),
      displaySmall: headingSmall.copyWith(color: baseColor),
      headlineMedium: headingMedium.copyWith(color: baseColor),
      headlineSmall: headingSmall.copyWith(color: baseColor),
      titleLarge: bodyLarge.copyWith(fontWeight: FontWeight.w600, color: baseColor),
      titleMedium: bodyMedium.copyWith(color: secondaryColor),
      titleSmall: bodySmall.copyWith(color: secondaryColor),
      bodyLarge: bodyLarge.copyWith(color: secondaryColor),
      bodyMedium: bodyMedium.copyWith(color: secondaryColor),
      bodySmall: bodySmall.copyWith(color: secondaryColor),
      labelLarge: bodyMedium.copyWith(fontWeight: FontWeight.w600, color: baseColor),
      labelSmall: bodySmall.copyWith(color: secondaryColor),
    );
  }
}
