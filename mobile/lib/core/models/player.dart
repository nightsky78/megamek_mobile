/// Mirrors the bridge's `megamekmobile.bridge.dto.PlayerDto` (see bridge/README.md).
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.team,
    required this.done,
    required this.gameMaster,
  });

  final int id;
  final String name;
  final int team;
  final bool done;
  final bool gameMaster;

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as int,
        name: json['name'] as String,
        team: json['team'] as int,
        done: json['done'] as bool,
        gameMaster: json['gameMaster'] as bool,
      );
}
