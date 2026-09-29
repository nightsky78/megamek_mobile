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

  test('Actions.addBot carries the difficulty when given', () {
    expect(Actions.addBot(botName: 'B', difficulty: 'hard'), {
      'type': 'action.add_bot',
      'botName': 'B',
      'difficulty': 'hard',
    });
  });

  test('Actions.deploy and moveTo match the bridge shape', () {
    expect(Actions.deploy(entityId: 1, x: 3, y: 4, facing: 2), {
      'type': 'action.deploy',
      'entityId': 1,
      'x': 3,
      'y': 4,
      'facing': 2,
    });
    expect(Actions.moveTo(entityId: 1, mode: 'RUN', x: 5, y: 6, facing: 1), {
      'type': 'action.move_to',
      'entityId': 1,
      'mode': 'RUN',
      'x': 5,
      'y': 6,
      'facing': 1,
    });
  });

  test('Actions.moveTo without a destination means stand still', () {
    expect(Actions.moveTo(entityId: 1, mode: 'WALK'), {
      'type': 'action.move_to',
      'entityId': 1,
      'mode': 'WALK',
    });
  });

  test('Actions.attackOptions picks the physical or weapon request', () {
    expect(
      Actions.attackOptions(entityId: 1, targetId: 2)['type'],
      'action.attack_options',
    );
    expect(
      Actions.attackOptions(entityId: 1, targetId: 2, physical: true)['type'],
      'action.physical_options',
    );
  });

  test('Actions.physical without target skips', () {
    expect(Actions.physical(entityId: 1), {
      'type': 'action.physical',
      'entityId': 1,
    });
    expect(Actions.physical(entityId: 1, targetId: 2, kind: 'KICK'), {
      'type': 'action.physical',
      'entityId': 1,
      'targetId': 2,
      'kind': 'KICK',
    });
  });

  test('force management actions', () {
    expect(Actions.removeUnit(7), {
      'type': 'action.remove_unit',
      'entityId': 7,
    });
    expect(Actions.setPilot(entityId: 7, gunnery: 3, piloting: 4), {
      'type': 'action.set_pilot',
      'entityId': 7,
      'gunnery': 3,
      'piloting': 4,
    });
    expect(Actions.setTeam(team: 2, botName: 'Bot1'), {
      'type': 'action.set_team',
      'team': 2,
      'botName': 'Bot1',
    });
    expect(Actions.newGame(), {'type': 'action.new_game'});
    expect(Actions.ping(), {'type': 'action.ping'});
  });
}
