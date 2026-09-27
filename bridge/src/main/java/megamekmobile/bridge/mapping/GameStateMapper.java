package megamekmobile.bridge.mapping;

import java.util.List;
import java.util.Map;

import megamek.common.Hex;
import megamek.common.Player;
import megamek.common.board.Board;
import megamek.common.enums.GamePhase;
import megamek.common.equipment.WeaponMounted;
import megamek.common.game.Game;
import megamek.common.units.Crew;
import megamek.common.units.Entity;

import megamekmobile.bridge.dto.BoardDto;
import megamekmobile.bridge.dto.EntityDto;
import megamekmobile.bridge.dto.GameStateSnapshot;
import megamekmobile.bridge.dto.HexDto;
import megamekmobile.bridge.dto.PlayerDto;
import megamekmobile.bridge.dto.WeaponDto;

/**
 * Translates MegaMek's live {@link Game} object graph into the bridge's own JSON DTOs (see
 * {@code docs/protocol-notes.md}, "JSON-Übersetzung: Prinzip"). Pure functions of MegaMek objects to
 * DTOs, kept free of any I/O or networking so they stay trivially unit-testable
 * ({@code GameStateMapperTest}).
 */
public final class GameStateMapper {

    private GameStateMapper() {
    }

    public static PlayerDto toDto(Player player) {
        return new PlayerDto(player.getId(), player.getName(), player.getTeam(), player.isDone(),
              player.getGameMaster());
    }

    public static WeaponDto toDto(WeaponMounted weapon) {
        return new WeaponDto(weapon.getEquipmentNum(), weapon.getName());
    }

    public static EntityDto toDto(Entity entity) {
        Crew crew = entity.getCrew();
        List<WeaponDto> weapons = entity.getWeaponList().stream().map(GameStateMapper::toDto).toList();

        return new EntityDto(
              entity.getId(),
              entity.getOwnerId(),
              entity.getChassis(),
              entity.getModel(),
              entity.getDisplayName(),
              entity.getBoardId(),
              entity.getPosition() == null ? -1 : entity.getPosition().getX(),
              entity.getPosition() == null ? -1 : entity.getPosition().getY(),
              entity.getFacing(),
              sumRemainingArmor(entity),
              entity.getTotalArmor(),
              sumRemainingInternal(entity),
              entity.getTotalInternal(),
              entity.isDestroyed(),
              crew == null ? "" : crew.getName(),
              crew == null ? 0 : crew.getGunnery(),
              crew == null ? 0 : crew.getHits(),
              weapons);
    }

    private static int sumRemainingArmor(Entity entity) {
        int total = 0;
        for (int loc = 0; loc < entity.locations(); loc++) {
            int armor = entity.getArmor(loc);
            if (armor > 0) {
                total += armor;
            }
        }
        return total;
    }

    private static int sumRemainingInternal(Entity entity) {
        int total = 0;
        for (int loc = 0; loc < entity.locations(); loc++) {
            int internal = entity.getInternal(loc);
            if (internal > 0) {
                total += internal;
            }
        }
        return total;
    }

    public static HexDto toDto(Hex hex, int x, int y) {
        return new HexDto(x, y, hex.getLevel(), hex.getTheme());
    }

    /**
     * Converts a whole board. Boards can be large (Total Warfare maps commonly run 16x17 to 40x40+
     * hexes); see CLAUDE.md "Bekannter Stand" for the documented follow-up of caching/diffing this
     * instead of re-sending it on every snapshot.
     */
    public static BoardDto toDto(int boardId, Board board) {
        List<HexDto> hexes = new java.util.ArrayList<>(board.getWidth() * board.getHeight());
        for (int y = 0; y < board.getHeight(); y++) {
            for (int x = 0; x < board.getWidth(); x++) {
                Hex hex = board.getHex(x, y);
                if (hex != null) {
                    hexes.add(toDto(hex, x, y));
                }
            }
        }
        return new BoardDto(boardId, board.getWidth(), board.getHeight(), hexes);
    }

    public static GameStateSnapshot snapshot(Game game, Integer localPlayerId) {
        List<PlayerDto> players = game.getPlayersList().stream().map(GameStateMapper::toDto).toList();
        List<EntityDto> entities = game.inGameTWEntities().stream().map(GameStateMapper::toDto).toList();

        Map<Integer, Board> boards = game.getBoards();
        List<BoardDto> boardDtos = boards.entrySet()
              .stream()
              .map(entry -> toDto(entry.getKey(), entry.getValue()))
              .toList();

        GamePhase phase = game.getPhase();
        return new GameStateSnapshot(
              phase == null ? "UNKNOWN" : phase.name(),
              game.getCurrentRound(),
              localPlayerId,
              players,
              entities,
              boardDtos);
    }
}
