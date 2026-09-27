package megamekmobile.bridge.dto;

/** One hex of the board. {@code theme} selects the tile art on the mobile client (e.g. "grass", "desert"). */
public record HexDto(int x, int y, int level, String theme) {
}
