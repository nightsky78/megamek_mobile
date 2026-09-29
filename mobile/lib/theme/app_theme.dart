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

  // Terrain palette (Phase: "full map details" - see hex_map_painter.dart).
  // Muted/earthy on purpose so unit markers (friendly/hostile above) still pop.
  static const Color terrainWater = Color(0xFF2D5F7C);
  static const Color terrainSwamp = Color(0xFF4A5A3A);
  static const Color terrainMud = Color(0xFF6B5335);
  static const Color terrainIce = Color(0xFFB8D4E0);
  static const Color terrainSnow = Color(0xFFE8EEF2);
  static const Color terrainSand = Color(0xFFC2A878);
  static const Color terrainTundra = Color(0xFF8A8F7A);
  static const Color terrainMagma = Color(0xFF8B3A1A);
  static const Color terrainFields = Color(0xFF7A8F4A);
  static const Color terrainIndustrial = Color(0xFF5A5A5A);
  static const Color terrainGeyser = Color(0xFF6FA8A0);
  static const Color terrainFortified = Color(0xFF4A4A55);
  static const Color terrainWoods = Color(0xFF2E5C2E);
  static const Color terrainJungle = Color(0xFF1F4D30);
  static const Color terrainRough = Color(0xFF6B6355);
  static const Color terrainRubble = Color(0xFF7A7268);
  static const Color terrainPavement = Color(0xFF454C52);
  static const Color terrainRoad = Color(0xFF9A8F6A);
  static const Color terrainRoadDirt = Color(0xFF8A7550);
  static const Color terrainBridge = Color(0xFF8B5A2B);
  static const Color terrainBuildingLight = Color(0xFFA89070);
  static const Color terrainBuildingMedium = Color(0xFF8A7860);
  static const Color terrainBuildingHeavy = Color(0xFF6B5D4F);
  static const Color terrainBuildingHardened = Color(0xFF4A4038);
  static const Color terrainFire = Color(0xFFE0692A);
  static const Color terrainSmoke = Color(0xFF9A9A9A);

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
