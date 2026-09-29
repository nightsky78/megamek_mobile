import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/core/models/actions.dart';

void main() {
  test('Actions.move matches the bridge ActionMessage shape', () {
    final json = Actions.move(entityId: 42, steps: ['FORWARDS', 'TURN_RIGHT']);
    expect(json, {
      'type': 'action.move',
      'entityId': 42,
      'steps': ['FORWARDS', 'TURN_RIGHT'],
    });
  });

  test('Actions.attack matches the bridge ActionMessage shape', () {
    final json = Actions.attack(entityId: 42, targetId: 17, weaponIds: [5, 9]);
    expect(json, {
      'type': 'action.attack',
      'entityId': 42,
      'targetId': 17,
      'weaponIds': [5, 9],
    });
  });

  test('Actions.endPhase defaults done to true', () {
    expect(Actions.endPhase(), {'type': 'action.end_phase', 'done': true});
    expect(Actions.endPhase(done: false), {
      'type': 'action.end_phase',
      'done': false,
    });
  });

  test('Actions.chat carries the text', () {
    expect(Actions.chat('hello'), {'type': 'action.chat', 'text': 'hello'});
  });

  test('Actions.addUnit matches the bridge ActionMessage shape', () {
    expect(Actions.addUnit(unitRef: 'Atlas AS7-D'), {
      'type': 'action.add_unit',
      'unitRef': 'Atlas AS7-D',
    });
  });

  test('Actions.addBot matches the bridge ActionMessage shape', () {
    expect(Actions.addBot(botName: 'Princess1'), {
      'type': 'action.add_bot',
      'botName': 'Princess1',
    });
  });

  test('Actions.addBotUnit matches the bridge ActionMessage shape', () {
    expect(
      Actions.addBotUnit(botName: 'Princess1', unitRef: 'Timber Wolf Prime'),
      {
        'type': 'action.add_bot_unit',
        'botName': 'Princess1',
        'unitRef': 'Timber Wolf Prime',
      },
    );
  });

  test('Actions.selectBoard matches the bridge ActionMessage shape', () {
    expect(Actions.selectBoard(boardNames: ['AGoAC Base']), {
      'type': 'action.select_board',
      'boardNames': ['AGoAC Base'],
    });
  });

  test('Actions.startGame has no extra fields', () {
    expect(Actions.startGame(), {'type': 'action.start_game'});
  });

  test('Actions.searchUnitCatalog omits unset optional filters', () {
    expect(Actions.searchUnitCatalog(text: 'atlas'), {
      'type': 'action.unit_catalog_search',
      'text': 'atlas',
    });
  });

  test('Actions.searchUnitCatalog includes every provided filter', () {
    expect(
      Actions.searchUnitCatalog(
        text: 'atlas',
        unitType: 'Mek',
        clanOnly: false,
        minTons: 50,
        maxTons: 100,
        limit: 20,
      ),
      {
        'type': 'action.unit_catalog_search',
        'text': 'atlas',
        'unitType': 'Mek',
        'clanOnly': false,
        'minTons': 50.0,
        'maxTons': 100.0,
        'limit': 20,
      },
    );
  });

  test(
    'MoveStep wire names match megamek.common.enums.MoveStepType constants',
    () {
      expect(MoveStep.forwards.wireName, 'FORWARDS');
      expect(MoveStep.backwards.wireName, 'BACKWARDS');
      expect(MoveStep.turnLeft.wireName, 'TURN_LEFT');
      expect(MoveStep.turnRight.wireName, 'TURN_RIGHT');
      expect(MoveStep.lateralLeft.wireName, 'LATERAL_LEFT');
      expect(MoveStep.lateralRight.wireName, 'LATERAL_RIGHT');
    },
  );
}
