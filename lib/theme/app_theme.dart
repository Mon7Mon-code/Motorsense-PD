import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// APP THEME — Parkinson's Tracker
// Aesthetic: Warm clinical — trusted, calm, accessible
// Primary: Deep teal  |  Accent: Amber  |  Base: Soft off-white
// ============================================================

class AppTheme {
  // --- Colour palette -----------------------------------------
  static const teal900  = Color(0xFF04342C);
  static const teal800  = Color(0xFF085041);
  static const teal700  = Color(0xFF0F6E56);
  static const teal600  = Color(0xFF0F8060);
  static const teal500  = Color(0xFF1D9E75);
  static const teal400  = Color(0xFF5DCAA5);
  static const teal100  = Color(0xFF9FE1CB);
  static const teal50   = Color(0xFFE1F5EE);

  static const amber600 = Color(0xFFBA7517);
  static const amber400 = Color(0xFFEF9F27);
  static const amber100 = Color(0xFFFAC775);
  static const amber50  = Color(0xFFFAEEDA);

  static const red600   = Color(0xFFA32D2D);
  static const red400   = Color(0xFFE24B4A);
  static const red50    = Color(0xFFFCEBEB);

  static const blue600  = Color(0xFF185FA5);
  static const blue400  = Color(0xFF378ADD);
  static const blue50   = Color(0xFFE6F1FB);

  static const neutral900 = Color(0xFF1A1A1A);
  static const neutral700 = Color(0xFF3D3D3A);
  static const neutral500 = Color(0xFF6B6B67);
  static const neutral300 = Color(0xFFB4B2A9);
  static const neutral400 = Color(0xFF888780);
  static const neutral600 = Color(0xFF5F5E5A);
  static const amber700   = Color(0xFF854F0B);
  static const red700     = Color(0xFF791F1F);
  static const neutral200 = Color(0xFFD3D1C7);
  static const neutral100 = Color(0xFFEAE8E0);
  static const neutral50  = Color(0xFFF5F4F0);

  // Semantic
  static const success  = teal500;
  static const warning  = amber400;
  static const danger   = red400;
  static const info     = blue400;

  // --- Status colours -----------------------------------------
  static Color statusColor(String flag) {
    switch (flag) {
      case 'needs-attention': return red400;
      case 'monitor': return amber400;
      default: return teal500;
    }
  }

  static Color statusBg(String flag) {
    switch (flag) {
      case 'needs-attention': return red50;
      case 'monitor': return amber50;
      default: return teal50;
    }
  }

  static String statusLabel(String flag) {
    switch (flag) {
      case 'needs-attention': return 'Needs attention';
      case 'monitor': return 'Monitor';
      default: return 'Stable';
    }
  }

  // --- Typography ---------------------------------------------
  static TextTheme get textTheme => GoogleFonts.dmSansTextTheme().copyWith(
    displayLarge: GoogleFonts.dmSans(
      fontSize: 32, fontWeight: FontWeight.w600, color: neutral900,
      letterSpacing: -0.5),
    displayMedium: GoogleFonts.dmSans(
      fontSize: 26, fontWeight: FontWeight.w600, color: neutral900,
      letterSpacing: -0.3),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 20, fontWeight: FontWeight.w600, color: neutral900),
    titleMedium: GoogleFonts.dmSans(
      fontSize: 16, fontWeight: FontWeight.w500, color: neutral900),
    titleSmall: GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w500, color: neutral700),
    bodyLarge: GoogleFonts.dmSans(
      fontSize: 16, fontWeight: FontWeight.w400, color: neutral700,
      height: 1.6),
    bodyMedium: GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: neutral700,
      height: 1.5),
    bodySmall: GoogleFonts.dmSans(
      fontSize: 12, fontWeight: FontWeight.w400, color: neutral500),
    labelLarge: GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w500, color: neutral900),
    labelSmall: GoogleFonts.dmSans(
      fontSize: 11, fontWeight: FontWeight.w500,
      color: neutral500, letterSpacing: 0.5),
  );

  // Mono — for metrics and scores
  static TextStyle get mono => GoogleFonts.dmMono(
    fontSize: 13, color: neutral700);
  static TextStyle get monoLarge => GoogleFonts.dmMono(
    fontSize: 22, fontWeight: FontWeight.w500, color: neutral900);

  // --- Light theme --------------------------------------------
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: teal600,
      onPrimary: Colors.white,
      secondary: amber400,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: neutral900,
      error: red400,
    ),
    scaffoldBackgroundColor: neutral50,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: neutral50,
      foregroundColor: neutral900,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 18, fontWeight: FontWeight.w600, color: neutral900),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: neutral200, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal600,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: teal600,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: teal600, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: teal600, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: teal600,
      unselectedItemColor: neutral300,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(
      color: neutral100,
      thickness: 0.5,
      space: 0,
    ),
  );
}

// --- Shared spacing constants --------------------------------
class Sp {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;

  static const screenPad = EdgeInsets.symmetric(horizontal: 20);
  static const cardPad   = EdgeInsets.all(16);
  static const sectionGap = SizedBox(height: 24);
  static const itemGap    = SizedBox(height: 12);
}
