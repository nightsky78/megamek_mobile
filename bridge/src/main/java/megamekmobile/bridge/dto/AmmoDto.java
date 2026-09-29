package megamekmobile.bridge.dto;

/** One ammo bin: {@code shots} remaining out of {@code maxShots}. */
public record AmmoDto(String name, String location, int shots, int maxShots) {
}
