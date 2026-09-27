package megamekmobile.bridge.mapping;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import megamek.common.Hex;
import megamek.common.Player;
import megamek.common.board.Board;
import megamek.common.board.Coords;
import megamek.common.units.BipedMek;

import megamekmobile.bridge.dto.BoardDto;
import megamekmobile.bridge.dto.EntityDto;
import megamekmobile.bridge.dto.HexDto;
import megamekmobile.bridge.dto.PlayerDto;

/**
 * Verifies the MegaMek-object -> bridge-DTO translation described in docs/protocol-notes.md, using real
 * MegaMek model classes (not mocks) so a change to their field/getter shape breaks this test instead of
 * silently producing wrong JSON.
 */
class GameStateMapperTest {

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
    }
}
