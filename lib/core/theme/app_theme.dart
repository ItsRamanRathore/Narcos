import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Cyberpunk/Neon Palette
  static const _primaryNeon = Color(0xFF00F3FF); // Cyan
  static const _accentPurple = Color(0xFF9D4EDD); // Deep Purple
  static const _backgroundDeep = Color(0xFF0B0B1A); // Very Dark Blue/Black
  static const _surfaceDark = Color(0xFF16162C); // Slightly lighter for surfaces
  static const _textGlow = Color(0xFFE0E0FF);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _primaryNeon,
      scaffoldBackgroundColor: _backgroundDeep,
      colorScheme: const ColorScheme.dark(
        primary: _primaryNeon,
        secondary: _accentPurple,
        background: _backgroundDeep,
        surface: _surfaceDark,
        onPrimary: Colors.black,
        onSurface: _textGlow,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: _textGlow, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: _textGlow, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: Colors.white70),
        bodyMedium: GoogleFonts.inter(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryNeon,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56), // Larger touch target
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: _primaryNeon.withOpacity(0.5),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: _surfaceDark.withOpacity(0.8),
        hintStyle: GoogleFonts.inter(color: Colors.white30),
        labelStyle: GoogleFonts.inter(color: Colors.white54),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryNeon, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, // We will use a custom floating nav
        selectedItemColor: _primaryNeon,
        unselectedItemColor: Colors.white38,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get light => dark; // Enforce dark theme
}
