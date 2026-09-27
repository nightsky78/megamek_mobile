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
  });
}
