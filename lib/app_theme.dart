import 'package:flutter/material.dart';

// This is your design system - all colors and styles in ONE place
// Why? So you can change the whole app's look by editing just this file!
class AppTheme {
  // Primary colors - the main brand color
  static const Color primaryColor = Color(0xFF2196F3); // Medical blue
  
  // Background colors - clean, professional
  static const Color backgroundColor = Color(0xFFF5F7FA); // Light gray-blue
  static const Color cardBackground = Colors.white;
  
  // Status colors - for showing severity levels
  static const Color successColor = Color(0xFF4CAF50); // Green - good/mild
  static const Color warningColor = Color(0xFFFF9800); // Orange - moderate
  static const Color dangerColor = Color(0xFFF44336);  // Red - severe
  
  // Text colors - hierarchy of importance
  static const Color textPrimary = Color(0xFF212121);   // Dark - main text
  static const Color textSecondary = Color(0xFF757575); // Gray - less important
  static const Color textLight = Color(0xFF9E9E9E);     // Light gray - hints
  
  // Spacing - consistent gaps between elements
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  
  // Border radius - rounded corners
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  
  // Shadows - subtle depth
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withAlpha(13),
    blurRadius: 10,
    offset: const Offset(0, 2),
  );

  // The main theme for your entire app
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
      ),
    );
  }
}