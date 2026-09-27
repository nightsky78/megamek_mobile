/// Builders for the JSON the app sends to the bridge on `/ws` (mirrors
/// `megamekmobile.bridge.dto.ActionMessage`; see bridge/README.md
/// "Client → Server messages"). Each step name must be a
/// `megamek.common.enums.MoveStepType` constant.
class Actions {
  Actions._();

  static Map<String, dynamic> move({required int entityId, required List<String> steps}) => {
        'type': 'action.move',
        'entityId': entityId,
        'steps': steps,
      };

  static Map<String, dynamic> attack({
    required int entityId,
    required int targetId,
    required List<int> weaponIds,
  }) =>
      {
        'type': 'action.attack',
        'entityId': entityId,
        'targetId': targetId,
        'weaponIds': weaponIds,
      };

  static Map<String, dynamic> endPhase({bool done = true}) => {
        'type': 'action.end_phase',
        'done': done,
      };

  static Map<String, dynamic> chat(String text) => {
        'type': 'action.chat',
        'text': text,
      };
}

/// The move-step vocabulary the bridge understands, in the order the MVP's
/// move builder UI offers them (see docs/protocol-notes.md).
enum MoveStep {
  forwards('FORWARDS', 'Forward'),
  backwards('BACKWARDS', 'Backward'),
  turnLeft('TURN_LEFT', 'Turn left'),
  turnRight('TURN_RIGHT', 'Turn right'),
  lateralLeft('LATERAL_LEFT', 'Side-step left'),
  lateralRight('LATERAL_RIGHT', 'Side-step right');

  const MoveStep(this.wireName, this.label);
  final String wireName;
  final String label;
}
