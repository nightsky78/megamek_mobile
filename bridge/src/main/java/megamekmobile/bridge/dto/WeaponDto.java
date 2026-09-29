package megamekmobile.bridge.dto;

/**
 * One weapon mounted on an entity.
 *
 * @param equipmentId index into the entity's equipment list; this is the {@code weaponIds} value the
 *                     mobile client must send back in an {@code action.attack} message
 * @param name        human-readable weapon name (e.g. "Medium Laser")
 * @param damage      damage per hit, or -1 when it depends on the ammo/cluster table
 * @param ranges      minimum, short, medium and long range in hexes (0 minimum = none)
 */
public record WeaponDto(
      int equipmentId,
      String name,
      String location,
      int damage,
      int heat,
      int minRange,
      int shortRange,
      int mediumRange,
      int longRange,
      boolean destroyed,
      boolean usedThisRound) {
}
