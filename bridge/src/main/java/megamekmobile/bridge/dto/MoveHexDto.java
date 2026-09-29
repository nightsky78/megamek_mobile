package megamekmobile.bridge.dto;

/** A hex a unit can reach, and the movement points the cheapest path there costs. */
public record MoveHexDto(int x, int y, int mp) {
}
