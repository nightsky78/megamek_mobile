/// Mirrors `megamekmobile.bridge.dto.TerrainEntryDto`.
class TerrainEntry {
  const TerrainEntry({
    required this.type,
    required this.level,
    required this.exits,
  });

  final int type;
  final int level;
  final int exits;

  /// True if this terrain feature exits toward hexside [direction] (0=N,
  /// clockwise to 5=NW, matching `megamek.common.board.Coords`'s convention
  /// and `HexGeometry`'s edge indexing).
  bool hasExit(int direction) => (exits & (1 << direction)) != 0;

  factory TerrainEntry.fromJson(Map<String, dynamic> json) => TerrainEntry(
    type: json['type'] as int,
    level: json['level'] as int,
    exits: json['exits'] as int,
  );
}

/// Mirrors `megamekmobile.bridge.dto.HexDto`.
class Hex {
  Hex({
    required this.x,
    required this.y,
    required this.level,
    this.theme,
    this.terrain = const [],
  }) : byType = {for (final t in terrain) t.type: t};

  final int x;
  final int y;
  final int level;
  final String? theme;
  final List<TerrainEntry> terrain;

  /// Precomputed for O(1) lookups - the painter checks "does this hex have
  /// terrain X" once per rendering pass, so this avoids repeated list scans.
  final Map<int, TerrainEntry> byType;

  factory Hex.fromJson(Map<String, dynamic> json) => Hex(
    x: json['x'] as int,
    y: json['y'] as int,
    level: json['level'] as int,
    theme: json['theme'] as String?,
    terrain: (json['terrain'] as List<dynamic>? ?? const [])
        .map((t) => TerrainEntry.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

/// Mirrors `megamekmobile.bridge.dto.BoardDto`.
class Board {
  const Board({
    required this.boardId,
    required this.width,
    required this.height,
    required this.hexes,
  });

  final int boardId;
  final int width;
  final int height;
  final List<Hex> hexes;

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    boardId: json['boardId'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
    hexes: (json['hexes'] as List<dynamic>)
        .map((h) => Hex.fromJson(h as Map<String, dynamic>))
        .toList(),
  );
}
