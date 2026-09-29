// Replies to the request/response style actions of the turn loop (see
// bridge/README.md): deployment hexes, movement envelope + path preview,
// to-hit numbers, and game report text.

typedef HexCoord = (int, int);

HexCoord _coord(Object? json) {
  final map = json as Map<String, dynamic>;
  return (map['x'] as int, map['y'] as int);
}

/// `state.deploy_options`.
class DeployOptions {
  const DeployOptions({required this.entityId, required this.hexes});

  final int entityId;
  final Set<HexCoord> hexes;

  factory DeployOptions.fromJson(Map<String, dynamic> json) => DeployOptions(
    entityId: json['entityId'] as int,
    hexes: (json['hexes'] as List<dynamic>).map(_coord).toSet(),
  );
}

/// `state.move_options`: every hex the unit can reach in [mode], with the MP
/// the cheapest path costs.
class MoveOptions {
  const MoveOptions({
    required this.entityId,
    required this.mode,
    required this.walkMp,
    required this.runMp,
    required this.jumpMp,
    required this.hexes,
  });

  final int entityId;
  final String mode;
  final int walkMp;
  final int runMp;
  final int jumpMp;
  final Map<HexCoord, int> hexes;

  factory MoveOptions.fromJson(Map<String, dynamic> json) => MoveOptions(
    entityId: json['entityId'] as int,
    mode: json['mode'] as String,
    walkMp: json['walkMp'] as int,
    runMp: json['runMp'] as int,
    jumpMp: json['jumpMp'] as int,
    hexes: {
      for (final h in json['hexes'] as List<dynamic>)
        _coord(h): (h as Map<String, dynamic>)['mp'] as int,
    },
  );
}

/// `state.move_preview`: the path the server-side path finder would take.
class MovePreview {
  const MovePreview({
    required this.entityId,
    required this.mode,
    required this.legal,
    required this.mpUsed,
    required this.facing,
    required this.path,
    this.message,
  });

  final int entityId;
  final String mode;
  final bool legal;
  final int mpUsed;
  final int facing;
  final List<HexCoord> path;
  final String? message;

  factory MovePreview.fromJson(Map<String, dynamic> json) => MovePreview(
    entityId: json['entityId'] as int,
    mode: json['mode'] as String,
    legal: json['legal'] as bool,
    mpUsed: json['mpUsed'] as int,
    facing: json['facing'] as int,
    path: (json['path'] as List<dynamic>).map(_coord).toList(),
    message: json['message'] as String?,
  );
}

/// One weapon or physical attack with its to-hit number.
class AttackOption {
  const AttackOption({
    required this.key,
    required this.name,
    required this.toHit,
    required this.probability,
    required this.description,
    required this.damage,
    required this.heat,
    required this.possible,
  });

  /// Equipment number (as a string) for weapons, `PUNCH_LEFT`/`KICK`/... for
  /// physical attacks.
  final String key;
  final String name;
  final int? toHit;
  final int probability;
  final String description;
  final int damage;
  final int heat;
  final bool possible;

  factory AttackOption.fromJson(Map<String, dynamic> json) => AttackOption(
    key: json['key'] as String,
    name: json['name'] as String,
    toHit: json['toHit'] as int?,
    probability: json['probability'] as int? ?? 0,
    description: json['description'] as String? ?? '',
    damage: json['damage'] as int? ?? 0,
    heat: json['heat'] as int? ?? 0,
    possible: json['possible'] as bool? ?? false,
  );
}

/// `state.attack_options`.
class AttackOptions {
  const AttackOptions({
    required this.entityId,
    required this.targetId,
    required this.range,
    required this.physical,
    required this.options,
  });

  final int entityId;
  final int targetId;
  final int range;
  final bool physical;
  final List<AttackOption> options;

  factory AttackOptions.fromJson(Map<String, dynamic> json) => AttackOptions(
    entityId: json['entityId'] as int,
    targetId: json['targetId'] as int,
    range: json['range'] as int,
    physical: json['physical'] as bool? ?? false,
    options: (json['options'] as List<dynamic>)
        .map((o) => AttackOption.fromJson(o as Map<String, dynamic>))
        .toList(),
  );
}

/// `state.report`: one chunk of the server's game report as plain text.
class ReportEntry {
  const ReportEntry({
    required this.round,
    required this.phase,
    required this.text,
  });

  final int round;
  final String phase;
  final String text;

  factory ReportEntry.fromJson(Map<String, dynamic> json) => ReportEntry(
    round: json['round'] as int,
    phase: json['phase'] as String,
    text: json['text'] as String,
  );
}
