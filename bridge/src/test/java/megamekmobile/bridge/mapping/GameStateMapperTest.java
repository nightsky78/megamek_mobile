package megamekmobile.bridge.mapping;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import megamek.common.Hex;
import megamek.common.Player;
import megamek.common.board.Board;
import megamek.common.board.Coords;
import megamek.common.equipment.EquipmentType;
import megamek.common.game.Game;
import megamek.common.units.BipedMek;
import megamek.common.units.Terrain;
import megamek.common.units.Terrains;

import megamekmobile.bridge.dto.BoardDto;
import megamekmobile.bridge.dto.EntityDto;
import megamekmobile.bridge.dto.GameStateSnapshot;
import megamekmobile.bridge.dto.HexDto;
import megamekmobile.bridge.dto.PlayerDto;
import megamekmobile.bridge.dto.TerrainEntryDto;

/**
 * Verifies the MegaMek-object -> bridge-DTO translation described in docs/protocol-notes.md, using real
 * MegaMek model classes (not mocks) so a change to their field/getter shape breaks this test instead of
 * silently producing wrong JSON.
 */
class GameStateMapperTest {

    @BeforeAll
    static void initializeMegaMekEquipmentTypes() {
        // Entity subclasses (BipedMek etc.) look up armor/weapon types from EquipmentType's static
        // lookup table during construction; MegaMek's own tests bootstrap it the same way (e.g.
        // vendor/megamek/megamek/unittests/megamek/common/TsmImplantTest.java) rather than relying on
        // it having been populated by some other code path already run in this JVM.
        EquipmentType.initializeTypes();
    }

    @Test
    void mapsPlayerFields() {
        Player player = new Player(3, "Aidan");
        player.setTeam(2);
        player.setDone(true);

        PlayerDto dto = GameStateMapper.toDto(player);

        assertEquals(3, dto.id());
        assertEquals("Aidan", dto.name());
        assertEquals(2, dto.team());
        assertTrue(dto.done());
        assertFalse(dto.gameMaster());
        assertFalse(dto.bot());
    }

    @Test
    void mapsBotPlayerFlag() {
        Player player = new Player(4, "Princess1");
        player.setBot(true);

        PlayerDto dto = GameStateMapper.toDto(player);

        assertTrue(dto.bot());
    }

    @Test
    void mapsEntityIdentityPositionAndDamage() {
        BipedMek mek = new BipedMek();
        mek.setId(42);
        mek.setChassis("Atlas");
        mek.setModel("AS7-D");
        mek.setOwner(new Player(1, "Owner"));
        mek.setPosition(new Coords(3, 4));
        mek.setFacing(2);
        mek.setArmor(10, 0);
        mek.setArmor(20, 1);
        mek.setInternal(5, 0);
        mek.setInternal(8, 1);

        EntityDto dto = GameStateMapper.toDto(mek);

        assertEquals(42, dto.id());
        assertEquals("Atlas", dto.chassis());
        assertEquals("AS7-D", dto.model());
        assertEquals(1, dto.ownerId());
        assertEquals(3, dto.x());
        assertEquals(4, dto.y());
        assertEquals(2, dto.facing());
        assertEquals(30, dto.armor());
        assertEquals(13, dto.internal());
        assertFalse(dto.destroyed());
        assertTrue(dto.weapons().isEmpty());
    }

    @Test
    void treatsMissingPositionAsMinusOne() {
        BipedMek mek = new BipedMek();
        mek.setId(7);

        EntityDto dto = GameStateMapper.toDto(mek);

        assertEquals(-1, dto.x());
        assertEquals(-1, dto.y());
    }

    @Test
    void mapsBoardHexesInOrder() {
        Board board = new Board(2, 1);
        board.setHex(0, 0, new Hex(1, "", "grass"));
        board.setHex(1, 0, new Hex(2, "", "desert"));

        BoardDto dto = GameStateMapper.toDto(7, board);

        assertEquals(7, dto.boardId());
        assertEquals(2, dto.width());
        assertEquals(1, dto.height());
        assertEquals(2, dto.hexes().size());

        HexDto first = dto.hexes().get(0);
        assertEquals(0, first.x());
        assertEquals(0, first.y());
        assertEquals(1, first.level());
        assertEquals("grass", first.theme());

        HexDto second = dto.hexes().get(1);
        assertEquals(1, second.x());
        assertEquals(2, second.level());
        assertEquals("desert", second.theme());
        assertTrue(first.terrain().isEmpty());
        assertTrue(second.terrain().isEmpty());
    }

    @Test
    void mapsHexTerrainEntriesFilteredToRenderedTypes() {
        Hex hex = new Hex(0);
        hex.addTerrain(new Terrain(Terrains.WOODS, 2)); // heavy woods, no exits
        hex.addTerrain(new Terrain(Terrains.ROAD, 1, true, 0b000011)); // normal road, exits N+NE
        hex.addTerrain(new Terrain(Terrains.INCLINE_TOP, 1, true, 0b000001)); // automatic - must be excluded

        HexDto dto = GameStateMapper.toDto(hex, 5, 6);

        assertEquals(5, dto.x());
        assertEquals(6, dto.y());
        assertEquals(0, dto.level());
        assertEquals(2, dto.terrain().size());

        TerrainEntryDto woods = dto.terrain().stream()
              .filter(t -> t.type() == Terrains.WOODS).findFirst().orElseThrow();
        assertEquals(2, woods.level());
        assertEquals(0, woods.exits());

        TerrainEntryDto road = dto.terrain().stream()
              .filter(t -> t.type() == Terrains.ROAD).findFirst().orElseThrow();
        assertEquals(1, road.level());
        assertEquals(3, road.exits());

        assertTrue(dto.terrain().stream().noneMatch(t -> t.type() == Terrains.INCLINE_TOP));
    }

    @Test
    void snapshotIncludesAvailableAndSelectedBoards() {
        Game game = new Game();
        game.getMapSettings().setBoardsAvailableVector(List.of("board1", "board2"));
        game.getMapSettings().setBoardsSelectedVector(List.of("board1"));

        GameStateSnapshot snapshot = GameStateMapper.snapshot(game, 1);

        assertEquals(List.of("board1", "board2"), snapshot.availableBoards());
        assertEquals(List.of("board1"), snapshot.selectedBoards());
    }

    @Test
    void snapshotDropsNullBoardSlotsInsteadOfThrowing() {
        // MapSettings pads boardsSelected with null when the board mosaic is resized before every
        // slot is filled (see MapSettings#setMapSize) - List.copyOf() rejects nulls outright, so
        // this reproduces the NullPointerException hit once a real game moved past LOUNGE.
        Game game = new Game();
        game.getMapSettings().setBoardsSelectedVector(Arrays.asList("board1", null));

        GameStateSnapshot snapshot = GameStateMapper.snapshot(game, 1);

        assertEquals(List.of("board1"), snapshot.selectedBoards());
    }
}
