import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/models/board.dart';
import '../../core/models/unit.dart';
import '../../theme/app_theme.dart';
import 'hex_geometry.dart';

/// Renders one board: terrain hexes, an optional highlighted set (move-step
/// preview), and unit markers with a facing tick and an armor bar.
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
      terrainPaint.color = _colorForLevel(hex.level);
      canvas.drawPath(path, terrainPaint);
      canvas.drawPath(path, borderPaint);
    }

    if (highlightedHexes.isNotEmpty) {
      final highlightPaint = Paint()..color = AppTheme.accent.withValues(alpha: 0.35);
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
    canvas.drawLine(center, tip, Paint()..strokeWidth = 2..color = Colors.white);

    _paintArmorBar(canvas, center, radius, unit.armorFraction);
  }

  void _paintArmorBar(Canvas canvas, Offset center, double radius, double fraction) {
    const barWidth = 20.0;
    const barHeight = 4.0;
    final topLeft = center.translate(-barWidth / 2, radius + 8);
    final backgroundRect = Rect.fromLTWH(topLeft.dx, topLeft.dy, barWidth, barHeight);
    canvas.drawRect(backgroundRect, Paint()..color = Colors.black54);
    final fillColor = fraction > 0.5
        ? AppTheme.armorGood
        : (fraction > 0.2 ? AppTheme.armorWarn : AppTheme.armorCritical);
    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, barWidth * fraction.clamp(0, 1), barHeight),
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
