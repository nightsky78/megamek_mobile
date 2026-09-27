import 'dart:math';
import 'dart:ui';

/// Flat-top offset hex grid math for the MVP's own board renderer (we draw
/// our own tiles rather than reusing MegaMek's Swing tileset - see
/// docs/licensing.md: MegaMek's art is CC-BY-NC-4.0, and a from-scratch
/// renderer sidesteps having to think about that for the app itself).
/// Column-major "odd-q" offset coordinates, matching the (x, y) pairs the
/// bridge sends (see `megamekmobile.bridge.dto.HexDto`).
class HexGeometry {
  const HexGeometry(this.size);

  /// Center-to-vertex radius.
  final double size;

  double get horizontalSpacing => size * 1.5;
  double get verticalSpacing => size * sqrt(3);

  Offset centerOf(int col, int row) {
    final x = horizontalSpacing * col + size;
    final y = verticalSpacing * (row + (col.isOdd ? 0.5 : 0.0)) + verticalSpacing / 2;
    return Offset(x, y);
  }

  Size canvasSizeFor(int boardWidth, int boardHeight) {
    final w = horizontalSpacing * boardWidth + size * 0.5 + size;
    final h = verticalSpacing * (boardHeight + 0.5) + verticalSpacing / 2 + size / 2;
    return Size(w, h);
  }

  List<Offset> hexCorners(Offset center) {
    return List.generate(6, (i) {
      final angle = (60 * i) * pi / 180;
      return Offset(center.dx + size * cos(angle), center.dy + size * sin(angle));
    });
  }

  /// Nearest-center hit test. Brute-force over every hex, which is more than
  /// fast enough for a single tap on boards up to the MVP's expected size
  /// (see CLAUDE.md "Bekannter Stand" for the documented follow-up if that
  /// ever needs to scale further).
  (int, int)? hexAt(Offset point, int boardWidth, int boardHeight) {
    (int, int)? best;
    var bestDistSquared = double.infinity;
    for (var col = 0; col < boardWidth; col++) {
      for (var row = 0; row < boardHeight; row++) {
        final distSquared = (centerOf(col, row) - point).distanceSquared;
        if (distSquared < bestDistSquared) {
          bestDistSquared = distSquared;
          best = (col, row);
        }
      }
    }
    if (bestDistSquared > size * size * 1.5) {
      return null;
    }
    return best;
  }
}
