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
    expect(Actions.endPhase(done: false), {'type': 'action.end_phase', 'done': false});
  });

  test('Actions.chat carries the text', () {
    expect(Actions.chat('hello'), {'type': 'action.chat', 'text': 'hello'});
  });

  test('MoveStep wire names match megamek.common.enums.MoveStepType constants', () {
    expect(MoveStep.forwards.wireName, 'FORWARDS');
    expect(MoveStep.backwards.wireName, 'BACKWARDS');
    expect(MoveStep.turnLeft.wireName, 'TURN_LEFT');
    expect(MoveStep.turnRight.wireName, 'TURN_RIGHT');
    expect(MoveStep.lateralLeft.wireName, 'LATERAL_LEFT');
    expect(MoveStep.lateralRight.wireName, 'LATERAL_RIGHT');
  });
}
