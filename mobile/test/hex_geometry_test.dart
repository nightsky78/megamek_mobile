import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/features/game/hex_geometry.dart';

void main() {
  group('HexGeometry', () {
    const geometry = HexGeometry(20);

    test('adjacent columns are offset by half the vertical spacing', () {
      final col0 = geometry.centerOf(0, 0);
      final col1 = geometry.centerOf(1, 0);

      expect(col1.dx - col0.dx, closeTo(geometry.horizontalSpacing, 0.001));
      expect(col1.dy - col0.dy, closeTo(geometry.verticalSpacing / 2, 0.001));
    });

    test('same column, consecutive rows are one vertical spacing apart', () {
      final row0 = geometry.centerOf(0, 0);
      final row1 = geometry.centerOf(0, 1);

      expect(row1.dy - row0.dy, closeTo(geometry.verticalSpacing, 0.001));
      expect(row1.dx, row0.dx);
    });

    test('hexAt finds the exact hex whose center is tapped', () {
      final center = geometry.centerOf(3, 2);
      expect(geometry.hexAt(center, 10, 10), (3, 2));
    });

    test('hexAt returns null well outside the board', () {
      expect(geometry.hexAt(const Offset(-1000, -1000), 10, 10), isNull);
    });

    test('hexCorners returns six points centered on the hex', () {
      final center = geometry.centerOf(0, 0);
      final corners = geometry.hexCorners(center);

      expect(corners, hasLength(6));
      for (final corner in corners) {
        expect((corner - center).distance, closeTo(geometry.size, 0.001));
      }
    });

    test('direction 0 (N) edge midpoint is straight above center', () {
      final center = geometry.centerOf(2, 2);
      final n = geometry.edgeMidpoint(center, 0);
      expect(n.dx, closeTo(center.dx, 0.001));
      expect(n.dy, lessThan(center.dy));
    });

    test('direction 3 (S) edge midpoint is straight below center', () {
      final center = geometry.centerOf(2, 2);
      final s = geometry.edgeMidpoint(center, 3);
      expect(s.dx, closeTo(center.dx, 0.001));
      expect(s.dy, greaterThan(center.dy));
    });

    test(
      'every edge midpoint sits at the hex apothem distance from center',
      () {
        final center = geometry.centerOf(1, 1);
        final apothem = geometry.size * sqrt(3) / 2;
        for (var d = 0; d < 6; d++) {
          expect(
            (geometry.edgeMidpoint(center, d) - center).distance,
            closeTo(apothem, 0.001),
          );
        }
      },
    );

    test('edgeMidpoint matches the average of its two hexCorners', () {
      final center = geometry.centerOf(0, 0);
      final corners = geometry.hexCorners(center);
      for (var d = 0; d < 6; d++) {
        final (a, b) = geometry.edgeCornerIndices(d);
        final expected = Offset(
          (corners[a].dx + corners[b].dx) / 2,
          (corners[a].dy + corners[b].dy) / 2,
        );
        expect(geometry.edgeMidpoint(center, d), expected);
      }
    });
  });
}
