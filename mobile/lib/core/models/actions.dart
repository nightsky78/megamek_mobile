/// Builders for the JSON the app sends to the bridge on `/ws` (mirrors
/// `megamekmobile.bridge.dto.ActionMessage`; see bridge/README.md
/// "Client → Server messages"). Each step name must be a
/// `megamek.common.enums.MoveStepType` constant.
class Actions {
  Actions._();

  static Map<String, dynamic> move({
    required int entityId,
    required List<String> steps,
  }) => {'type': 'action.move', 'entityId': entityId, 'steps': steps};

  static Map<String, dynamic> attack({
    required int entityId,
    required int targetId,
    required List<int> weaponIds,
  }) => {
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

  static Map<String, dynamic> addUnit({required String unitRef}) => {
    'type': 'action.add_unit',
    'unitRef': unitRef,
  };

  static Map<String, dynamic> addBot({required String botName}) => {
    'type': 'action.add_bot',
    'botName': botName,
  };

  static Map<String, dynamic> addBotUnit({
    required String botName,
    required String unitRef,
  }) => {'type': 'action.add_bot_unit', 'botName': botName, 'unitRef': unitRef};

  static Map<String, dynamic> selectBoard({required List<String> boardNames}) =>
      {'type': 'action.select_board', 'boardNames': boardNames};

  static Map<String, dynamic> startGame() => {'type': 'action.start_game'};

  static Map<String, dynamic> searchUnitCatalog({
    String? text,
    String? unitType,
    bool? clanOnly,
    double? minTons,
    double? maxTons,
    int? limit,
  }) => {
    'type': 'action.unit_catalog_search',
    'text': ?text,
    'unitType': ?unitType,
    'clanOnly': ?clanOnly,
    'minTons': ?minTons,
    'maxTons': ?maxTons,
    'limit': ?limit,
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
