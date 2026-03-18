import 'package:flutter/material.dart';

class AppColors {
  // Dark Theme Colors (Based on PrivateDashboard and DrawerWidget)
  static const Color darkBackground = Color(0xFF0A0E12);
  static const Color darkSurface = Color(0xFF15191C);
  static const Color darkSurfaceVariant = Color(0xFF1D2226);
  static const Color darkDrawerBackground = Color(0xFF0E1624);
  static const Color darkDrawerSelected = Color(0xFF1D293B);
  
  static const Color primaryBlue = Colors.blue;
  static const Color primaryBlueAccent = Colors.blueAccent;
  static const Color errorRed = Colors.red;
  static const Color successGreen = Colors.green;
  static const Color warningOrange = Colors.orange;
  
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Colors.white70;
  static const Color textTertiaryDark = Colors.white38;
  static const Color textDisabledDark = Colors.grey;

  // Light Theme Colors (Targeting User Reference)
  static const Color lightBackground = Color(0xFFE9F0F7); 
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceVariant = Color(0xFFF8FAFC);
  static const Color premiumBlue = Color(0xFF3B82F6);
  
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate-900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate-600
  static const Color textTertiaryLight = Color(0xFF94A3B8); // Slate-400
  static const Color lightDivider = Color(0xFFE2E8F0); // Slate-200 (Lighter gray for borders)
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryBlueAccent,
        surface: AppColors.darkSurface,
        background: AppColors.darkBackground,
        error: AppColors.errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
        onBackground: AppColors.textPrimaryDark,
        surfaceVariant: AppColors.darkSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white10,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkDrawerBackground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Colors.white70),
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.grey),
        labelSmall: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.lightBackground,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: AppColors.premiumBlue,
        secondary: AppColors.premiumBlue,
        surface: AppColors.lightSurface,
        background: AppColors.lightBackground,
        error: AppColors.errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onBackground: AppColors.textPrimaryLight,
        surfaceVariant: AppColors.lightSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightDivider),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightSurface,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: AppColors.textSecondaryLight),
        bodyMedium: TextStyle(color: AppColors.textSecondaryLight),
        bodySmall: TextStyle(color: AppColors.textTertiaryLight),
        labelSmall: TextStyle(color: AppColors.textTertiaryLight, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.premiumBlue,
      ),
    );
  }
}
