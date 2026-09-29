package megamekmobile.bridge.dto;

/**
 * To-hit information for one weapon or one physical attack against a specific target.
 *
 * @param key         weapon equipment id (as string) for ranged weapons, or "PUNCH"/"KICK" for physicals
 * @param toHit       the 2d6 target number, or null when the attack is impossible
 * @param probability percent chance to hit (0-100)
 */
public record AttackOptionDto(
      String key,
      String name,
      Integer toHit,
      int probability,
      String description,
      int damage,
      int heat,
      boolean possible) {
}
