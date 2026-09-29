import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/core/models/unit_summary.dart';

void main() {
  test('UnitSummary.fromJson parses the bridge README example', () {
    final summary = UnitSummary.fromJson({
      'ref': 'Atlas AS7-D',
      'chassis': 'Atlas',
      'model': 'AS7-D',
      'unitType': 'Mek',
      'tons': 100,
      'bv': 1897,
      'year': 3025,
      'techBase': 'Inner Sphere',
      'clan': false,
    });

    expect(summary.ref, 'Atlas AS7-D');
    expect(summary.chassis, 'Atlas');
    expect(summary.model, 'AS7-D');
    expect(summary.unitType, 'Mek');
    expect(summary.tons, 100.0);
    expect(summary.bv, 1897);
    expect(summary.year, 3025);
    expect(summary.techBase, 'Inner Sphere');
    expect(summary.clan, isFalse);
  });
}
