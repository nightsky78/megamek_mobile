package megamekmobile.bridge.dto;

/**
 * One terrain feature present in a hex (mirrors one entry of {@code megamek.common.Hex}'s internal
 * type-&gt;Terrain map). {@code type} is a {@code megamek.common.units.Terrains} constant (e.g.
 * {@code Terrains.WOODS == 1}); the mobile client mirrors the relevant constants as literals (see
 * {@code TerrainType} in the Flutter app) rather than round-tripping a lookup table, matching how
 * {@code MoveStepType}/{@code GamePhase} constants are already mirrored by convention (see
 * docs/protocol-notes.md). {@code level}'s meaning is terrain-type-specific (e.g. woods canopy density
 * 1-3, water depth, building class). {@code exits} is the 6-bit hexside connection mask
 * ({@code 1 << direction}, direction 0=N clockwise to 5=NW per {@code megamek.common.board.Coords}),
 * always resolved by the time a board is loaded - used for roads/rivers/bridges.
 */
public record TerrainEntryDto(int type, int level, int exits) {
}
