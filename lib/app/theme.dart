import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF1B1B1D);
  static const Color surfaceLight = Color(0xFF27272A);

  static const Color primary = Color(0xFF2F80ED);
  static const Color primaryDark = Color(0xFF1769D2);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9F);

  static const Color border = Color(0xFF303034);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surface,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),

        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),

        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),

        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),

        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),

        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF151517),
        indicatorColor: Color(0x332F80ED),

        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}