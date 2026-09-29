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
    final y =
        verticalSpacing * (row + (col.isOdd ? 0.5 : 0.0)) + verticalSpacing / 2;
    return Offset(x, y);
  }

  Size canvasSizeFor(int boardWidth, int boardHeight) {
    final w = horizontalSpacing * boardWidth + size * 0.5 + size;
    final h =
        verticalSpacing * (boardHeight + 0.5) + verticalSpacing / 2 + size / 2;
    return Size(w, h);
  }

  List<Offset> hexCorners(Offset center) {
    return List.generate(6, (i) {
      final angle = (60 * i) * pi / 180;
      return Offset(
        center.dx + size * cos(angle),
        center.dy + size * sin(angle),
      );
    });
  }

  /// The `hexCorners()` index pair bounding the hexside for MegaMek direction
  /// [direction] (0=N, clockwise to 5=NW - see `megamek.common.board.Coords`).
  /// Worked out from `hexCorners`'s ordering (corner 0 at 0°/east, clockwise
  /// in 60° steps on screen): the flat N/S edges are corner-pairs (4,5) and
  /// (1,2), giving edge-for-direction-d = corners ((d+4)%6, (d+5)%6).
  (int, int) edgeCornerIndices(int direction) {
    final start = (direction + 4) % 6;
    return (start, (start + 1) % 6);
  }

  /// Midpoint of the hexside for MegaMek direction [direction] (0=N..5=NW),
  /// used to draw roads/rivers/bridges from a `TerrainEntry.exits` bitmask.
  Offset edgeMidpoint(Offset center, int direction) {
    final corners = hexCorners(center);
    final (a, b) = edgeCornerIndices(direction);
    return Offset(
      (corners[a].dx + corners[b].dx) / 2,
      (corners[a].dy + corners[b].dy) / 2,
    );
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
