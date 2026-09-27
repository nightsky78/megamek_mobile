package megamekmobile.bridge.dto;

/**
 * One weapon mounted on an entity, as offered to the mobile client for attack declaration.
 *
 * @param equipmentId index into the entity's equipment list; this is the {@code weaponId} the mobile
 *                     client must send back in an {@code action.attack} message
 * @param name        human-readable weapon name (e.g. "Medium Laser")
 */
public record WeaponDto(int equipmentId, String name) {
}
