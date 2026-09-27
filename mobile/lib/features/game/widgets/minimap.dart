import 'package:flutter/material.dart';

import '../../../core/models/board.dart';
import '../../../core/models/unit.dart';
import '../../../theme/app_theme.dart';
import '../hex_geometry.dart';
import '../hex_map_painter.dart';

/// Small fixed-size overview (Phase 3: "Minimap als kleines Overlay statt
/// eigenes Fenster"), non-interactive - a corner of the real map, always
/// visible, no pan/zoom of its own.
class Minimap extends StatelessWidget {
  const Minimap({
    super.key,
    required this.board,
    required this.units,
    required this.unitColor,
  });

  final Board board;
  final List<Unit> units;
  final Color Function(Unit unit) unitColor;

  static const double _size = 120;

  @override
  Widget build(BuildContext context) {
    if (board.width == 0 || board.height == 0) {
      return const SizedBox.shrink();
    }
    final geometry = HexGeometry(_size / (board.width * 1.5 + 1));
    final canvasSize = geometry.canvasSizeFor(board.width, board.height);
    final scale = _size / canvasSize.width;

    return IgnorePointer(
      child: Container(
        width: _size,
        height: _size * (canvasSize.height / canvasSize.width),
        decoration: BoxDecoration(
          color: AppTheme.background.withValues(alpha: 0.85),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: CustomPaint(
              painter: HexMapPainter(
                board: board,
                units: units,
                geometry: geometry,
                unitColor: unitColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
