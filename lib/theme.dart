import 'package:flutter/material.dart';

class R {
  static const forest = Color(0xFF1B4D3E);
  static const forest2 = Color(0xFF24604E);
  static const forestFg = Color(0xFFF4F1EA);
  static const bg = Color(0xFFF3EFE6);
  static const surface = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1C2420);
  static const muted = Color(0xFF5C675F);
  static const ok = Color(0xFF1F6B45);
  static const warn = Color(0xFF9A5B12);
  static const danger = Color(0xFFA61F1A);
  static const pro = Color(0xFF9A5B12);
  static const proFg = Color(0xFFFFF8EB);
}

class RapistockTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: R.forest, brightness: Brightness.light),
      scaffoldBackgroundColor: R.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: R.forest,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: R.forest,
        foregroundColor: Colors.white,
      ),
    );
  }
}