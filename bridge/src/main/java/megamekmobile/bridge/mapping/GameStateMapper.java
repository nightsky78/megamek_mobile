package megamekmobile.bridge.mapping;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

import megamek.common.Hex;
import megamek.common.Player;
import megamek.common.board.Board;
import megamek.common.enums.GamePhase;
import megamek.common.equipment.AmmoMounted;
import megamek.common.equipment.AmmoType;
import megamek.common.equipment.Mounted;
import megamek.common.equipment.WeaponMounted;
import megamek.common.equipment.WeaponType;
import megamek.common.game.Game;
import megamek.common.game.GameTurn;
import megamek.common.loaders.MapSettings;
import megamek.common.units.Crew;
import megamek.common.units.Entity;
import megamek.common.units.Terrain;
import megamek.common.units.Terrains;
import megamek.common.units.UnitType;

import megamekmobile.bridge.dto.AmmoDto;
import megamekmobile.bridge.dto.BoardDto;
import megamekmobile.bridge.dto.EntityDto;
import megamekmobile.bridge.dto.GameResultDto;
import megamekmobile.bridge.dto.GameStateSnapshot;
import megamekmobile.bridge.dto.LocationDto;
import megamekmobile.bridge.dto.HexDto;
import megamekmobile.bridge.dto.PlayerDto;
import megamekmobile.bridge.dto.TerrainEntryDto;
import megamekmobile.bridge.dto.WeaponDto;

/**
 * Translates MegaMek's live {@link Game} object graph into the bridge's own JSON DTOs (see
 * {@code docs/protocol-notes.md}, "JSON-Übersetzung: Prinzip"). Pure functions of MegaMek objects to
 * DTOs, kept free of any I/O or networking so they stay trivially unit-testable
 * ({@code GameStateMapperTest}).
 */
public final class GameStateMapper {

    /**
     * Terrain types the mobile renderer draws. Excludes MegaMek's automatic/decorative types
     * (INCLINE_*, CLIFF_TOP/BOTTOM - see {@code Terrains.AUTOMATIC}) and the {@code *_FLUFF}/
     * tileset-selection-only constants, none of which affect gameplay-relevant terrain identity.
     * Pinned against {@code vendor/megamek} @ e601296070c (v0.51.0) - a future vendor bump should
     * diff {@code Terrains.java} against this set.
     */
    private static final Set<Integer> RENDERED_TERRAIN_TYPES = Set.of(
          Terrains.WOODS, Terrains.WATER, Terrains.ROUGH, Terrains.RUBBLE, Terrains.JUNGLE,
          Terrains.SAND, Terrains.TUNDRA, Terrains.MAGMA, Terrains.FIELDS, Terrains.INDUSTRIAL,
          Terrains.PAVEMENT, Terrains.ROAD, Terrains.SWAMP, Terrains.MUD, Terrains.RAPIDS,
          Terrains.ICE, Terrains.SNOW, Terrains.FIRE, Terrains.SMOKE, Terrains.GEYSER,
          Terrains.BUILDING, Terrains.BLDG_CF, Terrains.BLDG_ELEV,
          Terrains.BRIDGE, Terrains.BRIDGE_CF, Terrains.BRIDGE_ELEV,
          Terrains.FORTIFIED);

    private GameStateMapper() {
    }

    public static PlayerDto toDto(Player player) {
        return new PlayerDto(player.getId(), player.getName(), player.getTeam(), player.isDone(),
              player.getGameMaster(), player.isBot(), safeBv(player));
    }

    private static int safeBv(Player player) {
        try {
            return player.getBV();
        } catch (RuntimeException e) {
            return 0;
        }
    }

    public static WeaponDto toDto(WeaponMounted weapon) {
        WeaponType type = weapon.getType();
        return new WeaponDto(
              weapon.getEquipmentNum(),
              weapon.getName(),
              weapon.getEntity() == null ? "" : weapon.getEntity().getLocationAbbr(weapon.getLocation()),
              Math.max(0, type.getDamage()),
              Math.max(0, type.getHeat()),
              Math.max(0, type.getMinimumRange()),
              Math.max(0, type.getShortRange()),
              Math.max(0, type.getMediumRange()),
              Math.max(0, type.getLongRange()),
              weapon.isDestroyed() || weapon.isMissing(),
              weapon.isUsedThisRound());
    }

    public static EntityDto toDto(Entity entity) {
        Crew crew = entity.getCrew();
        List<WeaponDto> weapons = entity.getWeaponList().stream().map(GameStateMapper::toDto).toList();

        List<LocationDto> locations = new ArrayList<>();
        for (int loc = 0; loc < entity.locations(); loc++) {
            locations.add(toLocationDto(entity, loc));
        }

        List<AmmoDto> ammo = new ArrayList<>();
        for (AmmoMounted bin : entity.getAmmo()) {
            int maxShots = bin.getType() instanceof AmmoType ammoType ? ammoType.getShots() : 0;
            ammo.add(new AmmoDto(bin.getName(), entity.getLocationAbbr(bin.getLocation()),
                  Math.max(0, bin.getBaseShotsLeft()), maxShots));
        }

        List<String> damaged = new ArrayList<>();
        for (Mounted<?> mounted : entity.getEquipment()) {
            if (mounted.isDestroyed() || mounted.isMissing()) {
                damaged.add(mounted.getName());
            }
        }

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
              weapons,
              entity.getWeight(),
              safeBv(entity),
              UnitType.getTypeName(entity.getUnitType()),
              crew == null ? 5 : crew.getPiloting(),
              entity.getHeat(),
              entity.getHeatCapacity(),
              entity.getWalkMP(),
              entity.getRunMP(),
              entity.getJumpMP(),
              entity.isProne(),
              entity.isShutDown(),
              entity.isImmobile(),
              entity.isDeployed(),
              locations,
              ammo,
              damaged);
    }

    private static int safeBv(Entity entity) {
        try {
            return entity.calculateBattleValue();
        } catch (RuntimeException e) {
            return 0;
        }
    }

    private static LocationDto toLocationDto(Entity entity, int loc) {
        boolean rear = entity.hasRearArmor(loc);
        return new LocationDto(
              entity.getLocationName(loc),
              entity.getLocationAbbr(loc),
              Math.max(0, entity.getArmor(loc)),
              Math.max(0, entity.getOArmor(loc)),
              rear ? Math.max(0, entity.getArmor(loc, true)) : 0,
              rear ? Math.max(0, entity.getOArmor(loc, true)) : 0,
              Math.max(0, entity.getInternal(loc)),
              Math.max(0, entity.getOInternal(loc)),
              entity.isLocationBad(loc));
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
        List<TerrainEntryDto> terrain = hex.getTerrainTypesSet()
              .stream()
              .filter(RENDERED_TERRAIN_TYPES::contains)
              .sorted() // deterministic JSON regardless of the backing HashSet's iteration order
              .map(type -> {
                  Terrain t = hex.getTerrain(type);
                  return new TerrainEntryDto(type, t.getLevel(), t.getExits());
              })
              .toList();
        return new HexDto(x, y, hex.getLevel(), hex.getTheme(), terrain);
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

    /** Whether {@code playerId} is expected to act right now (mirrors {@code Client.isMyTurn()}). */
    public static boolean isPlayersTurn(Game game, int playerId) {
        GamePhase phase = game.getPhase();
        if (phase == null) {
            return false;
        }
        if (phase.isSimultaneous(game)) {
            return game.getTurnForPlayer(playerId) != null;
        }
        GameTurn turn = game.getTurn();
        return turn != null && turn.isValid(playerId, game);
    }

    /** Ids of the player's units that may take the current turn (deploy, move, fire, ...). */
    public static List<Integer> actableEntityIds(Game game, int playerId) {
        List<Integer> ids = new ArrayList<>();
        GamePhase phase = game.getPhase();
        if (phase == null || !isPlayersTurn(game, playerId)) {
            return ids;
        }
        GameTurn turn = phase.isSimultaneous(game) ? game.getTurnForPlayer(playerId) : game.getTurn();
        if (turn == null) {
            return ids;
        }
        for (Entity entity : game.inGameTWEntities()) {
            if (entity.getOwnerId() != playerId || entity.isDestroyed() || !turn.isValidEntity(entity, game)) {
                continue;
            }
            boolean eligible = switch (phase) {
                case DEPLOYMENT -> entity.shouldDeploy(game.getCurrentRound());
                case MOVEMENT -> entity.isDeployed() && entity.isEligibleForMovement();
                case FIRING -> entity.isDeployed() && entity.isEligibleForFiring();
                case PHYSICAL -> entity.isDeployed() && entity.isEligibleForPhysical();
                case TARGETING -> entity.isDeployed() && entity.isEligibleForTargetingPhase();
                default -> false;
            };
            if (eligible) {
                ids.add(entity.getId());
            }
        }
        return ids;
    }

    public static GameResultDto result(Game game, Integer localPlayerId) {
        if (game.getPhase() == null || !game.getPhase().isVictory()) {
            return null;
        }
        int winnerPlayer = game.getVictoryPlayerId();
        int winnerTeam = game.getVictoryTeam();
        Player local = localPlayerId == null ? null : game.getPlayer(localPlayerId);
        boolean won = localPlayerId != null && winnerPlayer != Player.PLAYER_NONE && winnerPlayer == localPlayerId;
        if (!won && local != null && winnerTeam != Player.TEAM_NONE && local.getTeam() == winnerTeam) {
            won = true;
        }
        String summary;
        if (winnerPlayer == Player.PLAYER_NONE && winnerTeam == Player.TEAM_NONE) {
            summary = "Draw - no winner";
        } else if (winnerPlayer != Player.PLAYER_NONE) {
            Player winner = game.getPlayer(winnerPlayer);
            summary = "Winner: " + (winner == null ? "player " + winnerPlayer : winner.getName());
        } else {
            summary = "Winner: team " + winnerTeam;
        }
        return new GameResultDto(winnerPlayer, winnerTeam, won, summary);
    }

    public static GameStateSnapshot snapshot(Game game, Integer localPlayerId) {
        List<PlayerDto> players = game.getPlayersList().stream().map(GameStateMapper::toDto).toList();
        List<EntityDto> entities = game.inGameTWEntities().stream().map(GameStateMapper::toDto).toList();

        Map<Integer, Board> boards = game.getBoards();
        List<BoardDto> boardDtos = boards.entrySet()
              .stream()
              .map(entry -> toDto(entry.getKey(), entry.getValue()))
              .toList();

        // boardsSelected can legitimately contain null entries - MapSettings pads unfilled mosaic
        // slots with null when the board grid is resized (see MapSettings#setMapSize) - which
        // List.copyOf() rejects outright, so those slots are dropped rather than surfaced as JSON
        // null (the mobile app has no representation for "no board chosen yet" per-slot anyway).
        MapSettings mapSettings = game.getMapSettings();
        List<String> availableBoards = mapSettings.getBoardsAvailableVector()
              .stream()
              .filter(Objects::nonNull)
              .toList();
        List<String> selectedBoards = mapSettings.getBoardsSelectedVector()
              .stream()
              .filter(Objects::nonNull)
              .toList();

        boolean myTurn = false;
        List<Integer> actable = List.of();
        Integer turnPlayerId = null;
        if (localPlayerId != null && localPlayerId >= 0) {
            myTurn = isPlayersTurn(game, localPlayerId);
            actable = actableEntityIds(game, localPlayerId);
        }
        GameTurn turn = game.getTurn();
        if (turn != null) {
            turnPlayerId = turn.playerId();
        }

        GamePhase phase = game.getPhase();
        return new GameStateSnapshot(
              phase == null ? "UNKNOWN" : phase.name(),
              game.getCurrentRound(),
              localPlayerId,
              players,
              entities,
              boardDtos,
              availableBoards,
              selectedBoards,
              turnPlayerId,
              myTurn,
              actable,
              result(game, localPlayerId));
    }
}
