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

  static Map<String, dynamic> addBot({
    required String botName,
    String? difficulty,
  }) => {
    'type': 'action.add_bot',
    'botName': botName,
    'difficulty': ?difficulty,
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
    int? minYear,
    int? maxYear,
    int? minBv,
    int? maxBv,
    String? techBase,
  }) => {
    'type': 'action.unit_catalog_search',
    'minYear': ?minYear,
    'maxYear': ?maxYear,
    'minBv': ?minBv,
    'maxBv': ?maxBv,
    'techBase': ?techBase,
    'text': ?text,
    'unitType': ?unitType,
    'clanOnly': ?clanOnly,
    'minTons': ?minTons,
    'maxTons': ?maxTons,
    'limit': ?limit,
  };

  static Map<String, dynamic> ping() => {'type': 'action.ping'};

  static Map<String, dynamic> deployOptions(int entityId) => {
    'type': 'action.deploy_options',
    'entityId': entityId,
  };

  static Map<String, dynamic> deploy({
    required int entityId,
    required int x,
    required int y,
    required int facing,
  }) => {
    'type': 'action.deploy',
    'entityId': entityId,
    'x': x,
    'y': y,
    'facing': facing,
  };

  static Map<String, dynamic> moveOptions({
    required int entityId,
    required String mode,
  }) => {'type': 'action.move_options', 'entityId': entityId, 'mode': mode};

  static Map<String, dynamic> movePreview({
    required int entityId,
    required String mode,
    int? x,
    int? y,
    int? facing,
  }) => {
    'type': 'action.move_preview',
    'entityId': entityId,
    'mode': mode,
    'x': ?x,
    'y': ?y,
    'facing': ?facing,
  };

  /// Omit [x]/[y] to stand still (optionally only turning to [facing]).
  static Map<String, dynamic> moveTo({
    required int entityId,
    required String mode,
    int? x,
    int? y,
    int? facing,
  }) => {
    'type': 'action.move_to',
    'entityId': entityId,
    'mode': mode,
    'x': ?x,
    'y': ?y,
    'facing': ?facing,
  };

  static Map<String, dynamic> attackOptions({
    required int entityId,
    required int targetId,
    bool physical = false,
  }) => {
    'type': physical ? 'action.physical_options' : 'action.attack_options',
    'entityId': entityId,
    'targetId': targetId,
  };

  /// Omit [targetId]/[kind] to skip the physical attack phase for this unit.
  static Map<String, dynamic> physical({
    required int entityId,
    int? targetId,
    String? kind,
  }) => {
    'type': 'action.physical',
    'entityId': entityId,
    'targetId': ?targetId,
    'kind': ?kind,
  };

  static Map<String, dynamic> removeUnit(int entityId) => {
    'type': 'action.remove_unit',
    'entityId': entityId,
  };

  static Map<String, dynamic> setPilot({
    required int entityId,
    int? gunnery,
    int? piloting,
  }) => {
    'type': 'action.set_pilot',
    'entityId': entityId,
    'gunnery': ?gunnery,
    'piloting': ?piloting,
  };

  /// [botName] null = the local player.
  static Map<String, dynamic> setTeam({required int team, String? botName}) => {
    'type': 'action.set_team',
    'team': team,
    'botName': ?botName,
  };

  static Map<String, dynamic> newGame() => {'type': 'action.new_game'};
}
