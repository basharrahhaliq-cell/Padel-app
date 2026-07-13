import 'package:flutter/material.dart';

/// "Let's Padel" brand: royal racket blue, deep navy, padel-ball lime —
/// sampled from the club logo.
class AppTheme {
  AppTheme._();

  static const Color courtBlue = Color(0xFF2557B8); // racket royal blue
  static const Color courtBlueDark = Color(0xFF173F63); // "PADEL" navy
  static const Color ballLime = Color(0xFFC9E62E); // padel ball
  static const Color surface = Color(0xFFF5F7FA);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: courtBlue,
      primary: courtBlue,
      secondary: ballLime,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: courtBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: courtBlue,
          foregroundColor: Colors.white,
          // Fixed height but NOT infinite width — an infinite minimum
          // width crashes any button placed inside a Row.
          minimumSize: const Size(64, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blueGrey.shade100),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
