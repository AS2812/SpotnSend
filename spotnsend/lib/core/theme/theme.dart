import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundSoft,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryMagenta,
        surface: AppColors.white,
        error: AppColors.error,
        outline: AppColors.grey,
        brightness: Brightness.light,
      ),
      textTheme: AppTypography.buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: AppTypography.headingSmall,
        foregroundColor: AppColors.primaryIndigo,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
  fillColor: AppColors.white.withValues(alpha: 0.9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: AppTypography.bodyLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
        ).merge(
          ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
          ? AppColors.grey.withValues(alpha: 0.4)
                  : AppColors.primaryBlue,
            ),
            foregroundColor: WidgetStateProperty.all(AppColors.white),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryBlue,
  unselectedItemColor: AppColors.grey.withValues(alpha: 0.7),
        selectedLabelStyle: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.bodySmall,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.white,
  selectedColor: AppColors.primaryBlue.withValues(alpha: 0.12),
        labelStyle: AppTypography.bodySmall,
        secondaryLabelStyle: AppTypography.bodySmall.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTypography.headingSmall,
        contentTextStyle: AppTypography.bodyMedium,
      ),
      cardTheme: CardThemeData(
  color: AppColors.white.withValues(alpha: 0.9),
        elevation: 2,
  shadowColor: AppColors.primaryIndigo.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryMagenta,
        surface: const Color(0xFF111217),
        error: AppColors.error,
  outline: AppColors.grey.withValues(alpha: 0.5),
        brightness: Brightness.dark,
      ),
      textTheme: AppTypography.buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF111217),
        elevation: 0,
        titleTextStyle: AppTypography.headingSmall.copyWith(color: AppColors.white),
        foregroundColor: AppColors.white,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF1C1D24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
      ),
      elevatedButtonTheme: light.elevatedButtonTheme,
      bottomNavigationBarTheme: light.bottomNavigationBarTheme.copyWith(
        backgroundColor: const Color(0xFF111217),
  unselectedItemColor: AppColors.white.withValues(alpha: 0.6),
      ),
      chipTheme: light.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1C1D24),
  selectedColor: AppColors.primaryBlue.withValues(alpha: 0.25),
  labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1D24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTypography.headingSmall.copyWith(color: AppColors.white),
  contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.white.withValues(alpha: 0.8)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1D24),
        elevation: 2,
        shadowColor: AppColors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
