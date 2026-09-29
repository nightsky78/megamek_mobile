package megamekmobile.bridge.dto;

import java.util.List;

/**
 * One hex of the board. {@code theme} selects the tile art on the mobile client (e.g. "grass",
 * "desert"). {@code terrain} lists the hex's terrain features (woods, water, roads, buildings, ...),
 * filtered to the set the mobile renderer actually draws - see
 * {@code GameStateMapper.RENDERED_TERRAIN_TYPES}.
 */
public record HexDto(int x, int y, int level, String theme, List<TerrainEntryDto> terrain) {
}
