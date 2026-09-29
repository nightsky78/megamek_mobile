import 'board.dart';
import 'player.dart';
import 'unit.dart';

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
  });

  final String phase;
  final int round;
  final int? localPlayerId;
  final List<Player> players;
  final List<Unit> units;
  final List<Board> boards;
  final List<String> availableBoards;
  final List<String> selectedBoards;

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
    'END' => 'End Phase',
    'VICTORY' => 'Victory',
    _ => phase,
  };

  bool get isKnownGroundPhase => _knownPhases.contains(phase);
}
