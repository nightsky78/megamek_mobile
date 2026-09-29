import 'weapon.dart';

/// Mirrors `megamekmobile.bridge.dto.LocationDto`.
class UnitLocation {
  const UnitLocation({
    required this.name,
    required this.abbr,
    required this.armor,
    required this.maxArmor,
    required this.rearArmor,
    required this.maxRearArmor,
    required this.internal,
    required this.maxInternal,
    required this.destroyed,
  });

  final String name;
  final String abbr;
  final int armor;
  final int maxArmor;
  final int rearArmor;
  final int maxRearArmor;
  final int internal;
  final int maxInternal;
  final bool destroyed;

  factory UnitLocation.fromJson(Map<String, dynamic> json) => UnitLocation(
    name: json['name'] as String,
    abbr: json['abbr'] as String,
    armor: json['armor'] as int,
    maxArmor: json['maxArmor'] as int,
    rearArmor: json['rearArmor'] as int,
    maxRearArmor: json['maxRearArmor'] as int,
    internal: json['internal'] as int,
    maxInternal: json['maxInternal'] as int,
    destroyed: json['destroyed'] as bool,
  );
}

/// Mirrors `megamekmobile.bridge.dto.AmmoDto`.
class UnitAmmo {
  const UnitAmmo({
    required this.name,
    required this.location,
    required this.shots,
    required this.maxShots,
  });

  final String name;
  final String location;
  final int shots;
  final int maxShots;

  factory UnitAmmo.fromJson(Map<String, dynamic> json) => UnitAmmo(
    name: json['name'] as String,
    location: json['location'] as String,
    shots: json['shots'] as int,
    maxShots: json['maxShots'] as int,
  );
}

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
    this.tons = 0,
    this.bv = 0,
    this.unitType = '',
    this.piloting = 5,
    this.heat = 0,
    this.heatCapacity = 0,
    this.walkMp = 0,
    this.runMp = 0,
    this.jumpMp = 0,
    this.prone = false,
    this.shutDown = false,
    this.immobile = false,
    this.deployed = true,
    this.locations = const [],
    this.ammo = const [],
    this.damagedEquipment = const [],
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
  final double tons;
  final int bv;
  final String unitType;
  final int piloting;
  final int heat;
  final int heatCapacity;
  final int walkMp;
  final int runMp;
  final int jumpMp;
  final bool prone;
  final bool shutDown;
  final bool immobile;
  final bool deployed;
  final List<UnitLocation> locations;
  final List<UnitAmmo> ammo;
  final List<String> damagedEquipment;

  /// Whether this unit has a known position on the board (see
  /// `GameStateMapper` on the bridge side: unplaced/undeployed units are sent
  /// with x = y = -1 rather than being omitted).
  bool get isDeployed => x >= 0 && y >= 0;

  double get armorFraction => totalArmor <= 0 ? 0 : armor / totalArmor;
  double get internalFraction =>
      totalInternal <= 0 ? 0 : internal / totalInternal;

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
    tons: (json['tons'] as num?)?.toDouble() ?? 0,
    bv: json['bv'] as int? ?? 0,
    unitType: json['unitType'] as String? ?? '',
    piloting: json['piloting'] as int? ?? 5,
    heat: json['heat'] as int? ?? 0,
    heatCapacity: json['heatCapacity'] as int? ?? 0,
    walkMp: json['walkMp'] as int? ?? 0,
    runMp: json['runMp'] as int? ?? 0,
    jumpMp: json['jumpMp'] as int? ?? 0,
    prone: json['prone'] as bool? ?? false,
    shutDown: json['shutDown'] as bool? ?? false,
    immobile: json['immobile'] as bool? ?? false,
    deployed: json['deployed'] as bool? ?? true,
    locations: (json['locations'] as List<dynamic>? ?? const [])
        .map((l) => UnitLocation.fromJson(l as Map<String, dynamic>))
        .toList(),
    ammo: (json['ammo'] as List<dynamic>? ?? const [])
        .map((a) => UnitAmmo.fromJson(a as Map<String, dynamic>))
        .toList(),
    damagedEquipment: (json['damagedEquipment'] as List<dynamic>? ?? const [])
        .cast<String>(),
  );
}
