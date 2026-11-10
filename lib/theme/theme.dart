import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'typography.dart';

/// 大蓝海 ThemeData
/// 深色主题：深海蓝底 + 帝国金强调，对应 H5 的暗色航海风格
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.abyss,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.abyss,
        secondary: AppColors.goldLight,
        onSecondary: AppColors.abyss,
        surface: AppColors.deep,
        onSurface: AppColors.parchment,
        error: AppColors.coral,
        onError: AppColors.parchment,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.abyss,
        foregroundColor: AppColors.parchment,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.brand,
        headlineMedium: AppTypography.h1,
        headlineSmall: AppTypography.h2,
        titleLarge: AppTypography.titleZh,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodySub,
        labelSmall: AppTypography.caption,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.abyss,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTypography.btnPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.sub, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.sub, fontSize: 12, letterSpacing: 1),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      iconTheme: const IconThemeData(color: AppColors.gold),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.abyss,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.sub,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
