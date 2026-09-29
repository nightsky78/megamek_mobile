/// Mirrors `megamekmobile.bridge.dto.WeaponDto`. `equipmentId` is what must be
/// sent back in an `action.attack` message's `weaponIds`.
class Weapon {
  const Weapon({
    required this.equipmentId,
    required this.name,
    this.location = '',
    this.damage = 0,
    this.heat = 0,
    this.minRange = 0,
    this.shortRange = 0,
    this.mediumRange = 0,
    this.longRange = 0,
    this.destroyed = false,
    this.usedThisRound = false,
  });

  final int equipmentId;
  final String name;
  final String location;
  final int damage;
  final int heat;
  final int minRange;
  final int shortRange;
  final int mediumRange;
  final int longRange;
  final bool destroyed;
  final bool usedThisRound;

  /// "3/6/9" style range summary for the unit detail sheet.
  String get rangeLabel => '$shortRange/$mediumRange/$longRange';

  factory Weapon.fromJson(Map<String, dynamic> json) => Weapon(
    equipmentId: json['equipmentId'] as int,
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    damage: json['damage'] as int? ?? 0,
    heat: json['heat'] as int? ?? 0,
    minRange: json['minRange'] as int? ?? 0,
    shortRange: json['shortRange'] as int? ?? 0,
    mediumRange: json['mediumRange'] as int? ?? 0,
    longRange: json['longRange'] as int? ?? 0,
    destroyed: json['destroyed'] as bool? ?? false,
    usedThisRound: json['usedThisRound'] as bool? ?? false,
  );
}
