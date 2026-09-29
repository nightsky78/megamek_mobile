import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/core/models/game_state_snapshot.dart';

// Mirrors the example in bridge/README.md exactly - if the bridge's JSON
// shape drifts, this test is the tripwire on the Dart side.
const _sampleJson = {
  'type': 'state.snapshot',
  'schemaVersion': 1,
  'phase': 'MOVEMENT',
  'round': 3,
  'localPlayerId': 1,
  'players': [
    {
      'id': 1,
      'name': 'Pilot1',
      'team': 1,
      'done': false,
      'gameMaster': false,
      'bot': false,
    },
  ],
  'entities': [
    {
      'id': 42,
      'ownerId': 1,
      'chassis': 'Atlas',
      'model': 'AS7-D',
      'displayName': 'Atlas AS7-D',
      'boardId': 0,
      'x': 7,
      'y': 12,
      'facing': 2,
      'armor': 180,
      'totalArmor': 212,
      'internal': 60,
      'totalInternal': 76,
      'destroyed': false,
      'pilotName': 'Grimm',
      'gunnery': 3,
      'pilotHits': 0,
      'weapons': [
        {'equipmentId': 5, 'name': 'AC/20'},
      ],
    },
  ],
  'boards': [
    {
      'boardId': 0,
      'width': 16,
      'height': 17,
      'hexes': [
        {'x': 0, 'y': 0, 'level': 0, 'theme': null},
      ],
    },
  ],
  'availableBoards': ['AGoAC Base', 'Sample Boards/CraterCityDay1'],
  'selectedBoards': ['AGoAC Base'],
};

void main() {
  test('GameStateSnapshot.fromJson parses the bridge README example', () {
    final snapshot = GameStateSnapshot.fromJson(_sampleJson);

    expect(snapshot.phase, 'MOVEMENT');
    expect(snapshot.phaseLabel, 'Movement');
    expect(snapshot.round, 3);
    expect(snapshot.localPlayerId, 1);

    expect(snapshot.players, hasLength(1));
    expect(snapshot.players.single.name, 'Pilot1');

    expect(snapshot.units, hasLength(1));
    final unit = snapshot.units.single;
    expect(unit.chassis, 'Atlas');
    expect(unit.isDeployed, isTrue);
    expect(unit.armorFraction, closeTo(180 / 212, 0.0001));
    expect(unit.weapons.single.name, 'AC/20');

    expect(snapshot.boards, hasLength(1));
    expect(snapshot.boards.single.hexes.single.theme, isNull);

    expect(snapshot.availableBoards, [
      'AGoAC Base',
      'Sample Boards/CraterCityDay1',
    ]);
    expect(snapshot.selectedBoards, ['AGoAC Base']);
  });

  test('availableBoards/selectedBoards default to empty when absent', () {
    final json = Map<String, dynamic>.from(_sampleJson)
      ..remove('availableBoards')
      ..remove('selectedBoards');

    final snapshot = GameStateSnapshot.fromJson(json);

    expect(snapshot.availableBoards, isEmpty);
    expect(snapshot.selectedBoards, isEmpty);
  });

  test('unit with x = -1 is not deployed', () {
    final json = Map<String, dynamic>.from(_sampleJson);
    final entities = List<Map<String, dynamic>>.from(json['entities'] as List);
    entities[0] = {...entities[0], 'x': -1, 'y': -1};
    json['entities'] = entities;

    final snapshot = GameStateSnapshot.fromJson(json);
    expect(snapshot.units.single.isDeployed, isFalse);
  });

  test('unknown phase names are labelled as-is and flagged unknown', () {
    final json = Map<String, dynamic>.from(_sampleJson)
      ..['phase'] = 'SOME_NEW_PHASE';
    final snapshot = GameStateSnapshot.fromJson(json);

    expect(snapshot.phaseLabel, 'SOME_NEW_PHASE');
    expect(snapshot.isKnownGroundPhase, isFalse);
  });
}
