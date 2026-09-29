import 'board.dart';
import 'player.dart';
import 'unit.dart';

/// Mirrors `megamekmobile.bridge.dto.GameResultDto`.
class GameResult {
  const GameResult({
    required this.winnerPlayerId,
    required this.winnerTeam,
    required this.localWon,
    required this.summary,
  });

  final int winnerPlayerId;
  final int winnerTeam;
  final bool localWon;
  final String summary;

  factory GameResult.fromJson(Map<String, dynamic> json) => GameResult(
    winnerPlayerId: json['winnerPlayerId'] as int,
    winnerTeam: json['winnerTeam'] as int,
    localWon: json['localWon'] as bool,
    summary: json['summary'] as String? ?? '',
  );
}

/// Mirrors `megamekmobile.bridge.dto.GameStateSnapshot` (the `"state.snapshot"`
/// message, see bridge/README.md). `phase` is the name of a MegaMek
/// `GamePhase` constant, e.g. `LOUNGE`, `MOVEMENT`, `FIRING`, `PHYSICAL`, `END`,
/// `VICTORY`.
class GameStateSnapshot {
  const GameStateSnapshot({
    required this.phase,
    required this.round,
    required this.localPlayerId,
    required this.players,
    required this.units,
    required this.boards,
    this.availableBoards = const [],
    this.selectedBoards = const [],
    this.turnPlayerId,
    this.myTurn = false,
    this.actableEntityIds = const [],
    this.result,
  });

  final String phase;
  final int round;
  final int? localPlayerId;
  final List<Player> players;
  final List<Unit> units;
  final List<Board> boards;
  final List<String> availableBoards;
  final List<String> selectedBoards;

  /// The player the server is currently waiting for, or null outside
  /// turn-based phases.
  final int? turnPlayerId;

  /// Whether the bridge's own player is expected to act right now.
  final bool myTurn;

  /// Units of the local player that may act in the current turn.
  final List<int> actableEntityIds;
  final GameResult? result;

  factory GameStateSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => GameStateSnapshot(
    phase: json['phase'] as String,
    round: json['round'] as int,
    localPlayerId: json['localPlayerId'] as int?,
    players: (json['players'] as List<dynamic>)
        .map((p) => Player.fromJson(p as Map<String, dynamic>))
        .toList(),
    units: (json['entities'] as List<dynamic>)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList(),
    boards: (json['boards'] as List<dynamic>)
        .map((b) => Board.fromJson(b as Map<String, dynamic>))
        .toList(),
    availableBoards:
        (json['availableBoards'] as List<dynamic>?)?.cast<String>() ?? const [],
    selectedBoards:
        (json['selectedBoards'] as List<dynamic>?)?.cast<String>() ?? const [],
    turnPlayerId: json['turnPlayerId'] as int?,
    myTurn: json['myTurn'] as bool? ?? false,
    actableEntityIds:
        (json['actableEntityIds'] as List<dynamic>?)?.cast<int>() ?? const [],
    result: json['result'] == null
        ? null
        : GameResult.fromJson(json['result'] as Map<String, dynamic>),
  );

  static const _knownPhases = [
    'LOUNGE',
    'DEPLOYMENT',
    'MOVEMENT',
    'FIRING',
    'PHYSICAL',
    'END',
    'VICTORY',
  ];

  /// Human-readable label for the phase bar (Phase 3 UI); falls back to the
  /// raw enum name for phases the MVP doesn't specifically label (see
  /// CLAUDE.md "Bekannter Stand").
  String get phaseLabel => switch (phase) {
    'LOUNGE' => 'Lobby',
    'DEPLOYMENT' => 'Deployment',
    'MOVEMENT' => 'Movement',
    'FIRING' => 'Firing',
    'PHYSICAL' => 'Physical',
    'INITIATIVE_REPORT' => 'Initiative',
    'MOVEMENT_REPORT' => 'Movement report',
    'OFFBOARD_REPORT' => 'Offboard report',
    'FIRING_REPORT' => 'Firing report',
    'PHYSICAL_REPORT' => 'Physical report',
    'END_REPORT' => 'End of round',
    'END' => 'End Phase',
    'VICTORY' => 'Victory',
    _ => phase,
  };

  bool get isKnownGroundPhase => _knownPhases.contains(phase);

  /// Report phases wait for the player to acknowledge (`action.end_phase`).
  bool get isReportPhase => phase.endsWith('_REPORT');

  Player? get localPlayer {
    for (final p in players) {
      if (p.id == localPlayerId) return p;
    }
    return null;
  }

  Unit? unitById(int id) {
    for (final u in units) {
      if (u.id == id) return u;
    }
    return null;
  }
}
