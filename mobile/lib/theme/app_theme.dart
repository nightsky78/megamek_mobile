import 'package:flutter/material.dart';

/// Touch-first theming for the MVP (Phase 3 requirement: "Eigenes, für Touch
/// designtes Theming statt Swing-Look"). Dark base: readable on a phone
/// outdoors/at a table, and closest to the tone of a BattleTech HUD.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF10151A);
  static const Color surface = Color(0xFF1B232B);
  static const Color accent = Color(0xFFE0A000);
  static const Color friendly = Color(0xFF3DA5D9);
  static const Color hostile = Color(0xFFD9463D);
  static const Color armorGood = Color(0xFF4CAF50);
  static const Color armorWarn = Color(0xFFE0A000);
  static const Color armorCritical = Color(0xFFD9463D);

  /// Minimum touch-target side length (Phase 3: "Große Touch-Ziele min. 44x44pt").
  static const double minTouchTarget = 44;

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: friendly,
        surface: surface,
        error: hostile,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: surface, elevation: 0),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: surface),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
        ),
      ),
    );
  }
}
