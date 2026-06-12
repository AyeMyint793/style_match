import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primary = Color(0xFF0F766E);      // Deep Teal
  static const Color accent = Color(0xFFF9735B);       // Coral
  static const Color background = Color(0xFFFAF7F2);  // Soft Warm
  static const Color text = Color(0xFF171717);         // Charcoal
  static const Color card = Color(0xFFFFFFFF);         // White
  static const Color muted = Color(0xFFE5E7EB);        // Cool Gray
  static const Color textSecondary = Color(0xFF6B7280); // Gray

  // Theme Data
  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: card,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: text),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF9CA3AF),
    ),
  );
}