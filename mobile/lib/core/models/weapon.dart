/// Mirrors `megamekmobile.bridge.dto.WeaponDto`. `equipmentId` is what must be
/// sent back in an `action.attack` message's `weaponIds`.
class Weapon {
  const Weapon({required this.equipmentId, required this.name});

  final int equipmentId;
  final String name;

  factory Weapon.fromJson(Map<String, dynamic> json) => Weapon(
    equipmentId: json['equipmentId'] as int,
    name: json['name'] as String,
  );
}
