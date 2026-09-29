import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/models/board.dart';
import '../../core/models/unit.dart';
import '../../theme/app_theme.dart';
import 'hex_geometry.dart';
import 'terrain_types.dart';

/// Renders one board: terrain hexes (elevation, then any terrain features -
/// woods, water, roads, buildings, etc., see [TerrainType]), an optional
/// highlighted set (move-step preview), and unit markers with a facing tick
/// and an armor bar.
class HexMapPainter extends CustomPainter {
  const HexMapPainter({
    required this.board,
    required this.units,
    required this.geometry,
    required this.unitColor,
    this.selectedUnitId,
    this.highlightedHexes = const {},
  });

  final Board board;
  final List<Unit> units;
  final HexGeometry geometry;
  final Color Function(Unit unit) unitColor;
  final int? selectedUnitId;
  final Set<(int, int)> highlightedHexes;

  // Ground-cover tints are mutually exclusive per hex (drawing more than one
  // as a blend muddies a hand-drawn palette) - first match in this priority
  // order wins when a hex somehow carries more than one.
  static const _groundCoverPriority = [
    TerrainType.water,
    TerrainType.swamp,
    TerrainType.mud,
    TerrainType.ice,
    TerrainType.snow,
    TerrainType.magma,
    TerrainType.sand,
    TerrainType.tundra,
    TerrainType.fields,
    TerrainType.industrial,
    TerrainType.geyser,
    TerrainType.fortified,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final terrainPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black45;

    for (final hex in board.hexes) {
      final center = geometry.centerOf(hex.x, hex.y);
      final path = Path()..addPolygon(geometry.hexCorners(center), true);

      // Paint order = layer order: each pass below only touches hexes that
      // actually carry that terrain type, so a bare hex costs one fill call.
      terrainPaint.color = _colorForLevel(hex.level);
      canvas.drawPath(path, terrainPaint);
      _paintGroundCoverTint(canvas, path, hex, center);
      _paintVegetation(canvas, hex, center);
      _paintTexture(canvas, hex, center);
      _paintPavement(canvas, path, hex);
      _paintLinear(canvas, hex, center);
      _paintStructure(canvas, hex, center);
      _paintOverlay(canvas, path, hex);
      // Border drawn last so opaque terrain fills (pavement, buildings) never
      // paint over the grid line.
      canvas.drawPath(path, borderPaint);
    }

    if (highlightedHexes.isNotEmpty) {
      final highlightPaint = Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.35);
      for (final coord in highlightedHexes) {
        final center = geometry.centerOf(coord.$1, coord.$2);
        final path = Path()..addPolygon(geometry.hexCorners(center), true);
        canvas.drawPath(path, highlightPaint);
      }
    }

    for (final unit in units) {
      if (!unit.isDeployed || unit.destroyed) {
        continue;
      }
      _paintUnit(canvas, unit);
    }
  }

  void _paintGroundCoverTint(Canvas canvas, Path path, Hex hex, Offset center) {
    TerrainType? chosen;
    for (final candidate in _groundCoverPriority) {
      if (hex.byType.containsKey(candidate.wireType)) {
        chosen = candidate;
        break;
      }
    }
    if (chosen == null) {
      return;
    }
    canvas.drawPath(path, Paint()..color = _groundCoverColor(chosen).withValues(alpha: 0.6));

    final rapids = hex.byType[TerrainType.rapids.wireType];
    if (chosen == TerrainType.water && rapids != null) {
      _paintRapids(canvas, hex, center, rapids.level);
    }
  }

  Color _groundCoverColor(TerrainType type) => switch (type) {
        TerrainType.water => AppTheme.terrainWater,
        TerrainType.swamp => AppTheme.terrainSwamp,
        TerrainType.mud => AppTheme.terrainMud,
        TerrainType.ice => AppTheme.terrainIce,
        TerrainType.snow => AppTheme.terrainSnow,
        TerrainType.magma => AppTheme.terrainMagma,
        TerrainType.sand => AppTheme.terrainSand,
        TerrainType.tundra => AppTheme.terrainTundra,
        TerrainType.fields => AppTheme.terrainFields,
        TerrainType.industrial => AppTheme.terrainIndustrial,
        TerrainType.geyser => AppTheme.terrainGeyser,
        TerrainType.fortified => AppTheme.terrainFortified,
        _ => Colors.transparent,
      };

  void _paintRapids(Canvas canvas, Hex hex, Offset center, int level) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.6);
    final rnd = _seededRandom(hex, 4);
    final count = level >= 2 ? 4 : 2;
    for (var i = 0; i < count; i++) {
      final pos = _randomPointInHex(rnd, center);
      final angle = rnd.nextDouble() * pi;
      final seg = Offset(cos(angle), sin(angle)) * 4;
      canvas.drawLine(pos - seg, pos + seg, paint);
    }
  }

  void _paintVegetation(Canvas canvas, Hex hex, Offset center) {
    final jungle = hex.byType[TerrainType.jungle.wireType];
    final woods = hex.byType[TerrainType.woods.wireType];
    final entry = jungle ?? woods;
    if (entry == null) {
      return;
    }
    final color = jungle != null ? AppTheme.terrainJungle : AppTheme.terrainWoods;
    const counts = {1: 5, 2: 8, 3: 11};
    const radii = {1: 2.0, 2: 2.5, 3: 3.0};
    final level = entry.level.clamp(1, 3);
    final count = counts[level]!;
    final dotRadius = radii[level]!;
    final rnd = _seededRandom(hex, 1);
    final paint = Paint()..color = color;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(_randomPointInHex(rnd, center), dotRadius, paint);
    }
  }

  void _paintTexture(Canvas canvas, Hex hex, Offset center) {
    final rough = hex.byType[TerrainType.rough.wireType];
    if (rough != null) {
      _paintRoughMarks(canvas, hex, center, rough.level >= 2 ? 10 : 5);
    }
    final rubble = hex.byType[TerrainType.rubble.wireType];
    if (rubble != null) {
      _paintRubbleMarks(canvas, hex, center, 3 + rubble.level.clamp(1, 6));
    }
  }

  void _paintRoughMarks(Canvas canvas, Hex hex, Offset center, int count) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppTheme.terrainRough.withValues(alpha: 0.8);
    final rnd = _seededRandom(hex, 2);
    for (var i = 0; i < count; i++) {
      final pos = _randomPointInHex(rnd, center);
      final angle = rnd.nextDouble() * pi;
      final seg = Offset(cos(angle), sin(angle)) * 3;
      canvas.drawLine(pos - seg, pos + seg, paint);
    }
  }

  void _paintRubbleMarks(Canvas canvas, Hex hex, Offset center, int count) {
    final paint = Paint()..color = AppTheme.terrainRubble.withValues(alpha: 0.85);
    final rnd = _seededRandom(hex, 3);
    for (var i = 0; i < count; i++) {
      final pos = _randomPointInHex(rnd, center);
      final side = 2.0 + rnd.nextDouble() * 2.0;
      canvas.drawRect(Rect.fromCenter(center: pos, width: side, height: side), paint);
    }
  }

  void _paintPavement(Canvas canvas, Path path, Hex hex) {
    if (!hex.byType.containsKey(TerrainType.pavement.wireType)) {
      return;
    }
    canvas.drawPath(path, Paint()..color = AppTheme.terrainPavement.withValues(alpha: 0.9));
  }

  void _paintLinear(Canvas canvas, Hex hex, Offset center) {
    final road = hex.byType[TerrainType.road.wireType];
    if (road != null) {
      _paintRoad(canvas, center, road);
    }
    final bridge = hex.byType[TerrainType.bridge.wireType];
    if (bridge != null) {
      _paintBridge(canvas, center, bridge);
    }
  }

  void _paintRoad(Canvas canvas, Offset center, TerrainEntry road) {
    final isDirtOrGravel = road.level >= 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDirtOrGravel ? 2.5 : 4.0
      ..strokeCap = StrokeCap.round
      ..color = isDirtOrGravel ? AppTheme.terrainRoadDirt : AppTheme.terrainRoad;
    _drawSpokesOrDot(canvas, center, road, paint);
  }

  void _paintBridge(Canvas canvas, Offset center, TerrainEntry bridge) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.terrainBridge;
    _drawSpokesOrDot(canvas, center, bridge, paint);

    // Short perpendicular plank ticks along each span, distinguishing a
    // bridge from a plain road even where both terrain types coexist.
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppTheme.terrainBridge.withValues(alpha: 0.7);
    for (var direction = 0; direction < 6; direction++) {
      if (!bridge.hasExit(direction)) {
        continue;
      }
      final edge = geometry.edgeMidpoint(center, direction);
      final along = edge - center;
      final normal = Offset(-along.dy, along.dx) / along.distance * 4;
      final mid = center + along * 0.5;
      canvas.drawLine(mid - normal, mid + normal, tickPaint);
    }
  }

  /// Draws one line per set bit in [entry]'s exits mask from the hex center to
  /// that hexside's midpoint - a through-road reads as one continuous line, a
  /// turn as a bent line, a dead-end as a single spoke. An isolated stub with
  /// no exits still gets a small dot so it isn't invisible.
  void _drawSpokesOrDot(Canvas canvas, Offset center, TerrainEntry entry, Paint paint) {
    var drewAny = false;
    for (var direction = 0; direction < 6; direction++) {
      if (entry.hasExit(direction)) {
        canvas.drawLine(center, geometry.edgeMidpoint(center, direction), paint);
        drewAny = true;
      }
    }
    if (!drewAny) {
      canvas.drawCircle(center, paint.strokeWidth * 0.8, Paint()..color = paint.color);
    }
  }

  void _paintStructure(Canvas canvas, Hex hex, Offset center) {
    final building = hex.byType[TerrainType.building.wireType];
    if (building == null) {
      return;
    }
    final elev = hex.byType[TerrainType.bldgElev.wireType]?.level ?? 1;
    final color = switch (building.level) {
      1 => AppTheme.terrainBuildingLight,
      2 => AppTheme.terrainBuildingMedium,
      3 => AppTheme.terrainBuildingHeavy,
      _ => AppTheme.terrainBuildingHardened,
    };

    final side = geometry.size * 1.2;
    final rect = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black45,
    );

    // Floor-count divider lines, capped so a very tall building doesn't clutter.
    final floors = elev.clamp(1, 5);
    if (floors > 1) {
      final floorPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black38;
      for (var i = 1; i < floors; i++) {
        final y = rect.top + (rect.height / floors) * i;
        canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.right - 2, y), floorPaint);
      }
    }
  }

  void _paintOverlay(Canvas canvas, Path path, Hex hex) {
    final fire = hex.byType[TerrainType.fire.wireType];
    if (fire != null) {
      final alpha = 0.35 + (fire.level.clamp(1, 4) - 1) * 0.12;
      canvas.drawPath(path, Paint()..color = AppTheme.terrainFire.withValues(alpha: alpha));
    }
    final smoke = hex.byType[TerrainType.smoke.wireType];
    if (smoke != null) {
      final alpha = 0.3 + (smoke.level.clamp(1, 4) - 1) * 0.1;
      canvas.drawPath(path, Paint()..color = AppTheme.terrainSmoke.withValues(alpha: alpha));
    }
  }

  /// Stable per-hex pseudo-random source: same hex + same [salt] always
  /// produces the same scatter pattern, so terrain doesn't visibly "jitter"
  /// between repaints (pan/zoom, snapshot updates).
  Random _seededRandom(Hex hex, int salt) => Random(hex.x * 7919 + hex.y * 104729 + salt);

  Offset _randomPointInHex(Random rnd, Offset center) {
    final angle = rnd.nextDouble() * 2 * pi;
    final dist = rnd.nextDouble() * geometry.size * 0.7;
    return center + Offset(cos(angle), sin(angle)) * dist;
  }

  void _paintUnit(Canvas canvas, Unit unit) {
    final center = geometry.centerOf(unit.x, unit.y);
    final radius = geometry.size * 0.5;
    final isSelected = unit.id == selectedUnitId;

    final markerPaint = Paint()..color = unitColor(unit);
    canvas.drawCircle(center, radius, markerPaint);

    if (isSelected) {
      final selectionPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white;
      canvas.drawCircle(center, radius + 3, selectionPaint);
    }

    // Facing tick: facing 0 points toward the top of the hex, then clockwise
    // in 60-degree steps. Our own convention (see hex_geometry.dart doc
    // comment) - not pixel-matched to MegaMek's own renderer, which this app
    // deliberately does not reuse (docs/licensing.md).
    final angle = (unit.facing * 60 - 90) * pi / 180;
    final tip = center + Offset(cos(angle), sin(angle)) * (radius + 6);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    _paintArmorBar(canvas, center, radius, unit.armorFraction);
  }

  void _paintArmorBar(
    Canvas canvas,
    Offset center,
    double radius,
    double fraction,
  ) {
    const barWidth = 20.0;
    const barHeight = 4.0;
    final topLeft = center.translate(-barWidth / 2, radius + 8);
    final backgroundRect = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      barWidth,
      barHeight,
    );
    canvas.drawRect(backgroundRect, Paint()..color = Colors.black54);
    final fillColor = fraction > 0.5
        ? AppTheme.armorGood
        : (fraction > 0.2 ? AppTheme.armorWarn : AppTheme.armorCritical);
    canvas.drawRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        barWidth * fraction.clamp(0, 1),
        barHeight,
      ),
      Paint()..color = fillColor,
    );
  }

  Color _colorForLevel(int level) {
    if (level < 0) {
      return const Color(0xFF1A3A5C);
    }
    if (level == 0) {
      return const Color(0xFF2E4A2E);
    }
    final clamped = level.clamp(1, 6);
    final t = clamped / 6;
    return Color.lerp(const Color(0xFF4A5A32), const Color(0xFF8A7A5C), t)!;
  }

  @override
  bool shouldRepaint(covariant HexMapPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.units != units ||
        oldDelegate.selectedUnitId != selectedUnitId ||
        oldDelegate.highlightedHexes != highlightedHexes;
  }
}

// Provides Canvas.drawPolygon-style convenience without pulling in an extra
// package: Path has no addPolygon in dart:ui directly usable from here, so
// this small extension keeps hex_map_painter.dart readable.
extension PathPolygon on Path {
  void addPolygon(List<Offset> points, bool close) {
    if (points.isEmpty) {
      return;
    }
    moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      lineTo(point.dx, point.dy);
    }
    if (close) {
      this.close();
    }
  }
}
