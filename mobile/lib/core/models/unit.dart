import 'weapon.dart';

/// Mirrors `megamekmobile.bridge.dto.EntityDto`. Named `Unit` on the Dart side
/// ("Entity" reads oddly outside the Java/MegaMek codebase and would shadow
/// nothing useful here).
class Unit {
  const Unit({
    required this.id,
    required this.ownerId,
    required this.chassis,
    required this.model,
    required this.displayName,
    required this.boardId,
    required this.x,
    required this.y,
    required this.facing,
    required this.armor,
    required this.totalArmor,
    required this.internal,
    required this.totalInternal,
    required this.destroyed,
    required this.pilotName,
    required this.gunnery,
    required this.pilotHits,
    required this.weapons,
  });

  final int id;
  final int ownerId;
  final String chassis;
  final String model;
  final String displayName;
  final int boardId;
  final int x;
  final int y;
  final int facing;
  final int armor;
  final int totalArmor;
  final int internal;
  final int totalInternal;
  final bool destroyed;
  final String pilotName;
  final int gunnery;
  final int pilotHits;
  final List<Weapon> weapons;

  /// Whether this unit has a known position on the board (see
  /// `GameStateMapper` on the bridge side: unplaced/undeployed units are sent
  /// with x = y = -1 rather than being omitted).
  bool get isDeployed => x >= 0 && y >= 0;

  double get armorFraction => totalArmor <= 0 ? 0 : armor / totalArmor;
  double get internalFraction => totalInternal <= 0 ? 0 : internal / totalInternal;

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'] as int,
        ownerId: json['ownerId'] as int,
        chassis: json['chassis'] as String,
        model: json['model'] as String,
        displayName: json['displayName'] as String,
        boardId: json['boardId'] as int,
        x: json['x'] as int,
        y: json['y'] as int,
        facing: json['facing'] as int,
        armor: json['armor'] as int,
        totalArmor: json['totalArmor'] as int,
        internal: json['internal'] as int,
        totalInternal: json['totalInternal'] as int,
        destroyed: json['destroyed'] as bool,
        pilotName: json['pilotName'] as String,
        gunnery: json['gunnery'] as int,
        pilotHits: json['pilotHits'] as int,
        weapons: (json['weapons'] as List<dynamic>)
            .map((w) => Weapon.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}
