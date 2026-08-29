import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QatalyTheme {
  static const Color primary = Color(0xFF7C3AED);     // Electric Violet
  static const Color secondary = Color(0xFFA3E635);   // Neon Lime
  static const Color background = Color(0xFF0F0F11);  // Noir Black
  static const Color cardBase = Color(0xFF1E1E24);    // Charcoal Dark
  static const Color accent = Color(0xFFEF4444);      // Cyber Red
  
  static const Color border = Colors.black;
  static const double borderWidth = 2.0;

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark().copyWith(
        primary: primary,
        secondary: secondary,
        error: accent,
        surface: cardBase,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
        displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: GoogleFonts.inter(color: Colors.white),
        bodyMedium: GoogleFonts.inter(color: Colors.white70),
      ),
    );
  }
}
