/// Mirrors `megamekmobile.bridge.dto.HexDto`.
class Hex {
  const Hex({required this.x, required this.y, required this.level, this.theme});

  final int x;
  final int y;
  final int level;
  final String? theme;

  factory Hex.fromJson(Map<String, dynamic> json) => Hex(
        x: json['x'] as int,
        y: json['y'] as int,
        level: json['level'] as int,
        theme: json['theme'] as String?,
      );
}

/// Mirrors `megamekmobile.bridge.dto.BoardDto`.
class Board {
  const Board({required this.boardId, required this.width, required this.height, required this.hexes});

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
