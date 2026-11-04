import 'package:flutter/material.dart';

class AppTheme {
  // Sfondi calmi e vellutati (Midnight Obsidian)
  static const Color background = Color(0xFF090C13);
  static const Color surface = Color(0xFF111622);
  static const Color surfaceLight = Color(0xFF182030);
  static const Color border = Color(0xFF212B3E);

  // Accenti iconici e calmi
  static const Color accentMint = Color(0xFF2DD4BF);       // Nordic Jade / Mint calmo acustico
  static const Color accentGold = Color(0xFFF6C974);       // Oro caldo e rassicurante
  static const Color accentIndigo = Color(0xFF818CF8);     // Viola celeste distensivo
  static const Color accentEmerald = Color(0xFF10B981);    // Verde smeraldo per conferme/successo

  // Alias compatibilità per palette iconica
  static const Color accentAmber = accentGold;
  static const Color accentCyan = accentMint;
  static const Color accentPink = Color(0xFFF472B6);

  // Tipografia serena e distensiva
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color activeLyricGlow = Color(0xFFFFFBEB);  // Bianco avorio luminoso e calmo per la vista

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentMint,
      colorScheme: const ColorScheme.dark(
        primary: accentMint,
        secondary: accentGold,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentMint,
          foregroundColor: const Color(0xFF080B11),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
