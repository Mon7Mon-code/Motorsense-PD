import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// APP THEME v2 — Warm, alive, premium
// Direction: Apple Health × wellness app × clinical trust
// Base: warm cream | Primary: rich forest green | Accent: golden amber
// ============================================================

class AppTheme {
  // --- Colour palette -----------------------------------------

  // Forest green — rich, warm, trustworthy
  static const green900 = Color(0xFF0D2B1F);
  static const green800 = Color(0xFF1A3D2B);
  static const green700 = Color(0xFF1E5C3A);
  static const green600 = Color(0xFF237A4B);
  static const green500 = Color(0xFF2D9E63);
  static const green400 = Color(0xFF4DBF82);
  static const green300 = Color(0xFF7DD4A4);
  static const green200 = Color(0xFFB0E8C8);
  static const green100 = Color(0xFFD4F2E2);
  static const green50  = Color(0xFFEEF9F3);

  // Keep teal aliases for compatibility
  static const teal900  = green900;
  static const teal800  = green800;
  static const teal700  = green700;
  static const teal600  = green600;
  static const teal500  = green500;
  static const teal400  = green400;
  static const teal300  = green300;
  static const teal200  = green200;
  static const teal100  = green100;
  static const teal50   = green50;

  // Golden amber — warm, encouraging, not alarming
  static const amber700 = Color(0xFF92530A);
  static const amber600 = Color(0xFFB8690F);
  static const amber500 = Color(0xFFD4820F);
  static const amber400 = Color(0xFFE9A020);
  static const amber300 = Color(0xFFF2BC5E);
  static const amber100 = Color(0xFFFADFA0);
  static const amber50  = Color(0xFFFDF3DC);

  // Warm red
  static const red700 = Color(0xFF8B1E1E);
  static const red600 = Color(0xFFAB2828);
  static const red400 = Color(0xFFD94F4F);
  static const red100 = Color(0xFFF8DADA);
  static const red50  = Color(0xFFFDF0F0);

  // Warm blue
  static const blue600 = Color(0xFF1A5CA8);
  static const blue400 = Color(0xFF3B82D4);
  static const blue50  = Color(0xFFE8F1FB);

  // Warm neutrals — cream base, not cold grey
  static const neutral900 = Color(0xFF1C1917);
  static const neutral800 = Color(0xFF292524);
  static const neutral700 = Color(0xFF44403C);
  static const neutral600 = Color(0xFF57534E);
  static const neutral500 = Color(0xFF78716C);
  static const neutral400 = Color(0xFFA8A29E);
  static const neutral300 = Color(0xFFC4BDB8);
  static const neutral200 = Color(0xFFE7E0DA);
  static const neutral100 = Color(0xFFF0EBE5);
  static const neutral50  = Color(0xFFFAF7F4);
  static const neutral0   = Color(0xFFFFFDFB);

  // Semantic
  static const success = green500;
  static const warning = amber400;
  static const danger  = red400;
  static const info    = blue400;

  // --- Gradients ----------------------------------------------
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green700, green500],
  );

  static const gradientWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E5C3A), Color(0xFF2D9E63)],
  );

  static const gradientAmber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber600, amber400],
  );

  static const gradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D2B1F), Color(0xFF1A3D2B)],
  );

  // --- Status -------------------------------------------------
  static Color statusColor(String flag) {
    switch (flag) {
      case 'needs-attention': return red400;
      case 'monitor':         return amber400;
      default:                return green500;
    }
  }

  static Color statusBg(String flag) {
    switch (flag) {
      case 'needs-attention': return red50;
      case 'monitor':         return amber50;
      default:                return green50;
    }
  }

  static String statusLabel(String flag) {
    switch (flag) {
      case 'needs-attention': return 'Needs attention';
      case 'monitor':         return 'Monitor';
      default:                return 'Stable';
    }
  }

  // --- Typography ---------------------------------------------
  static TextTheme get textTheme => GoogleFonts.dmSansTextTheme().copyWith(
    displayLarge:  GoogleFonts.dmSans(
        fontSize: 34, fontWeight: FontWeight.w700,
        color: neutral900, letterSpacing: -0.8, height: 1.1),
    displayMedium: GoogleFonts.dmSans(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: neutral900, letterSpacing: -0.5, height: 1.15),
    displaySmall:  GoogleFonts.dmSans(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: neutral900, letterSpacing: -0.3),
    titleLarge:    GoogleFonts.dmSans(
        fontSize: 20, fontWeight: FontWeight.w600, color: neutral900),
    titleMedium:   GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: neutral900),
    titleSmall:    GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w500, color: neutral700),
    bodyLarge:     GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: neutral700, height: 1.6),
    bodyMedium:    GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: neutral700, height: 1.5),
    bodySmall:     GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: neutral500),
    labelLarge:    GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w500, color: neutral900),
    labelSmall:    GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: neutral500, letterSpacing: 0.4),
  );

  static TextStyle get mono => GoogleFonts.dmMono(
      fontSize: 13, color: neutral700, letterSpacing: -0.2);
  static TextStyle get monoLarge => GoogleFonts.dmMono(
      fontSize: 22, fontWeight: FontWeight.w500, color: neutral900);
  static TextStyle get monoSmall => GoogleFonts.dmMono(
      fontSize: 11, color: neutral500);

  // --- Light theme --------------------------------------------
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary:    green600,
      onPrimary:  Colors.white,
      secondary:  green600,
      onSecondary: Colors.white,
      surface:    neutral0,
      onSurface:  neutral900,
      error:      red400,
    ),
    scaffoldBackgroundColor: neutral50,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: neutral50,
      foregroundColor: neutral900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: neutral200,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: neutral900),
    ),
    cardTheme: CardThemeData(
      color: neutral0,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: neutral200, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: green600,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: green600,
        minimumSize: const Size(double.infinity, 56),
        side: const BorderSide(color: green600, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutral0,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neutral200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neutral200)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green600, width: 1.5)),
      hintStyle: GoogleFonts.dmSans(color: neutral400, fontSize: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: neutral0,
      selectedItemColor: green600,
      unselectedItemColor: neutral400,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(
        color: neutral100, thickness: 0.5, space: 0),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? green600 : neutral400),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? green200
              : neutral200),
    ),
  );
}

// --- Spacing ------------------------------------------------
class Sp {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 16.0;
  static const lg  = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;

  static const screenPad = EdgeInsets.symmetric(horizontal: 20);
  static const cardPad   = EdgeInsets.all(18);
  static const sectionGap = SizedBox(height: 24);
  static const itemGap    = SizedBox(height: 12);
}

// --- Shadow helpers -----------------------------------------
class AppShadow {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF1C1917).withValues(alpha:0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF1C1917).withValues(alpha:0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get strong => [
    BoxShadow(
      color: const Color(0xFF1C1917).withValues(alpha:0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: const Color(0xFF1C1917).withValues(alpha:0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}