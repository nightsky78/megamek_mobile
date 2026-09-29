package megamekmobile.bridge.dto;

/** Armor/structure of one hit location. {@code maxRearArmor} is 0 when the location has no rear armor. */
public record LocationDto(
      String name,
      String abbr,
      int armor,
      int maxArmor,
      int rearArmor,
      int maxRearArmor,
      int internal,
      int maxInternal,
      boolean destroyed) {
}
