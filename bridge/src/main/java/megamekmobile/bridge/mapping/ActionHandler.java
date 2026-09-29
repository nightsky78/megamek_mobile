package megamekmobile.bridge.mapping;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Vector;

import megamek.client.Client;
import megamek.client.bot.princess.Princess;
import megamek.common.Player;
import megamek.common.ToHitData;
import megamek.common.actions.EntityAction;
import megamek.common.actions.KickAttackAction;
import megamek.common.actions.PunchAttackAction;
import megamek.common.actions.WeaponAttackAction;
import megamek.common.board.AllowedDeploymentHelper;
import megamek.common.board.Board;
import megamek.common.board.BoardLocation;
import megamek.common.board.Coords;
import megamek.common.board.ElevationOption;
import megamek.common.compute.Compute;
import megamek.common.enums.GamePhase;
import megamek.common.enums.MoveStepType;
import megamek.common.equipment.AmmoMounted;
import megamek.common.equipment.AmmoType;
import megamek.common.equipment.WeaponMounted;
import megamek.common.game.Game;
import megamek.common.loaders.MapSettings;
import megamek.common.loaders.MekSummary;
import megamek.common.loaders.MekSummaryCache;
import megamek.common.moves.MoveStep;
import megamek.common.moves.MovePath;
import megamek.common.pathfinder.ShortestPathFinder;
import megamek.common.units.Crew;
import megamek.common.units.Entity;
import megamek.common.units.Mek;
import megamek.common.units.Targetable;
import megamek.logging.MMLogger;

import megamekmobile.bridge.BotManager;
import megamekmobile.bridge.dto.ActionMessage;
import megamekmobile.bridge.dto.AttackOptionDto;
import megamekmobile.bridge.dto.AttackOptionsMessage;
import megamekmobile.bridge.dto.CoordDto;
import megamekmobile.bridge.dto.DeployOptionsMessage;
import megamekmobile.bridge.dto.ErrorMessage;
import megamekmobile.bridge.dto.MoveHexDto;
import megamekmobile.bridge.dto.MoveOptionsMessage;
import megamekmobile.bridge.dto.MovePreviewMessage;

/**
 * Turns a mobile client's {@link ActionMessage} into the matching call on MegaMek's own {@link Client},
 * exactly the way the Swing UI would (see {@code docs/protocol-notes.md} for the full table). Kept
 * independent of the WebSocket layer; request/response style actions (move envelope, to-hit numbers,
 * deployment hexes, ...) return their reply message(s) for the requesting client only, everything
 * else reaches all clients through the normal game-listener -> snapshot path.
 */
public final class ActionHandler {

    private static final MMLogger LOGGER = MMLogger.create(ActionHandler.class);

    private final Client client;
    private final BotManager botManager;
    private final String serverPassword;

    public ActionHandler(Client client, BotManager botManager, String serverPassword) {
        this.client = client;
        this.botManager = botManager;
        this.serverPassword = serverPassword;
    }

    /** Handles one action; returns replies for the requesting client (usually empty). */
    public List<Object> handle(ActionMessage message) {
        if (message.type() == null) {
            LOGGER.warn("Action message without a type ignored: {}", message);
            return List.of();
        }
        return switch (message.type()) {
            case ActionMessage.MOVE -> none(() -> handleMove(message));
            case ActionMessage.ATTACK -> none(() -> handleAttack(message));
            case ActionMessage.END_PHASE -> none(() -> handleEndPhase(message));
            case ActionMessage.CHAT -> none(() -> handleChat(message));
            case ActionMessage.ADD_UNIT -> none(() -> handleAddUnit(message));
            case ActionMessage.ADD_BOT -> none(() -> handleAddBot(message));
            case ActionMessage.ADD_BOT_UNIT -> none(() -> handleAddBotUnit(message));
            case ActionMessage.SELECT_BOARD -> none(() -> handleSelectBoard(message));
            case ActionMessage.START_GAME -> none(this::handleStartGame);
            case ActionMessage.DEPLOY_OPTIONS -> handleDeployOptions(message);
            case ActionMessage.DEPLOY -> handleDeploy(message);
            case ActionMessage.MOVE_OPTIONS -> handleMoveOptions(message);
            case ActionMessage.MOVE_PREVIEW -> handleMovePreview(message);
            case ActionMessage.MOVE_TO -> handleMoveTo(message);
            case ActionMessage.ATTACK_OPTIONS -> handleAttackOptions(message, false);
            case ActionMessage.PHYSICAL_OPTIONS -> handleAttackOptions(message, true);
            case ActionMessage.PHYSICAL -> handlePhysical(message);
            case ActionMessage.REMOVE_UNIT -> handleRemoveUnit(message);
            case ActionMessage.SET_PILOT -> handleSetPilot(message);
            case ActionMessage.SET_TEAM -> handleSetTeam(message);
            case ActionMessage.NEW_GAME -> handleNewGame();
            default -> {
                LOGGER.warn("Unknown action type '{}' ignored", message.type());
                yield List.of();
            }
        };
    }

    private static List<Object> none(Runnable action) {
        action.run();
        return List.of();
    }

    private static List<Object> error(String text) {
        return List.of(new ErrorMessage(text));
    }

    // ---------------------------------------------------------------- lobby

    private void handleAddUnit(ActionMessage message) {
        Entity entity = loadEntityOrWarn(message.unitRef());
        if (entity == null) {
            return;
        }
        entity.setOwner(client.getLocalPlayer());
        client.sendAddEntity(List.of(entity));
    }

    private void handleAddBot(ActionMessage message) {
        if (message.botName() == null || message.botName().isBlank()) {
            LOGGER.warn("action.add_bot without botName ignored");
            return;
        }
        botManager.addBot(message.botName(), message.difficulty());
    }

    private void handleAddBotUnit(ActionMessage message) {
        if (message.botName() == null || message.botName().isBlank()) {
            LOGGER.warn("action.add_bot_unit without botName ignored");
            return;
        }
        Princess princess = botManager.get(message.botName());
        if (princess == null) {
            LOGGER.warn("action.add_bot_unit for unknown bot '{}' ignored", message.botName());
            return;
        }
        Entity entity = loadEntityOrWarn(message.unitRef());
        if (entity == null) {
            return;
        }
        entity.setOwner(princess.getLocalPlayer());
        princess.sendAddEntity(List.of(entity));
    }

    private void handleSelectBoard(ActionMessage message) {
        List<String> boardNames = nullToEmpty(message.boardNames());
        if (boardNames.isEmpty()) {
            LOGGER.warn("action.select_board with no boardNames ignored");
            return;
        }
        MapSettings mapSettings = MapSettings.getInstance(client.getGame().getMapSettings());
        mapSettings.setBoardsSelectedVector(boardNames);
        client.sendMapSettings(mapSettings);
    }

    private void handleStartGame() {
        client.sendDone(true);
        for (Princess princess : botManager.all()) {
            princess.sendDone(true);
        }
    }

    private List<Object> handleRemoveUnit(ActionMessage message) {
        Entity entity = entityOrNull(message.entityId());
        if (entity == null) {
            return error("Unknown unit");
        }
        Client owner = clientOwning(entity.getOwnerId());
        if (owner == null) {
            return error("Cannot remove a unit of another player");
        }
        owner.sendDeleteEntity(entity.getId());
        return List.of();
    }

    private List<Object> handleSetPilot(ActionMessage message) {
        Entity entity = entityOrNull(message.entityId());
        if (entity == null || entity.getCrew() == null) {
            return error("Unknown unit");
        }
        Client owner = clientOwning(entity.getOwnerId());
        if (owner == null) {
            return error("Cannot edit a unit of another player");
        }
        Crew crew = entity.getCrew();
        if (message.gunnery() != null) {
            crew.setGunnery(clampSkill(message.gunnery()), 0);
        }
        if (message.piloting() != null) {
            crew.setPiloting(clampSkill(message.piloting()), 0);
        }
        owner.sendUpdateEntity(entity);
        return List.of();
    }

    private static int clampSkill(int value) {
        return Math.max(0, Math.min(8, value));
    }

    private List<Object> handleSetTeam(ActionMessage message) {
        if (message.team() == null) {
            return error("Missing team");
        }
        Client target = client;
        if (message.botName() != null && !message.botName().isBlank()) {
            target = botManager.get(message.botName());
            if (target == null) {
                return error("Unknown bot");
            }
        }
        target.getLocalPlayer().setTeam(message.team());
        target.sendPlayerInfo();
        return List.of();
    }

    private List<Object> handleNewGame() {
        GamePhase phase = client.getGame().getPhase();
        if (phase != null && phase.isVictory()) {
            client.sendDone(true);
        } else if (serverPassword != null && !serverPassword.isBlank()) {
            client.sendChat("/reset " + serverPassword);
        } else {
            return error("Ending a running game needs --server-password on the bridge");
        }
        return List.of();
    }

    // ------------------------------------------------------------ deployment

    private List<Object> handleDeployOptions(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = entityOrNull(message.entityId());
        if (entity == null) {
            return error("Unknown unit");
        }
        Board board = game.getBoard(entity.getBoardId());
        List<CoordDto> hexes = new ArrayList<>();
        if (board != null && !entity.isBoardProhibited(board)) {
            for (int y = 0; y < board.getHeight(); y++) {
                for (int x = 0; x < board.getWidth(); x++) {
                    Coords coords = new Coords(x, y);
                    if (isDeployable(game, board, entity, coords)) {
                        hexes.add(new CoordDto(x, y));
                    }
                }
            }
        }
        return List.of(new DeployOptionsMessage(entity.getId(), hexes));
    }

    private static boolean isDeployable(Game game, Board board, Entity entity, Coords coords) {
        if (!board.isLegalDeployment(coords, entity)) {
            return false;
        }
        if (!game.getEntitiesVector(coords, entity.getBoardId()).isEmpty()) {
            return false;
        }
        AllowedDeploymentHelper helper = new AllowedDeploymentHelper(entity, coords, board, board.getHex(coords),
              game);
        return !helper.findAllowedElevations().isEmpty() || helper.findAllowedFacings(0) != null
              && helper.findAllowedFacings(0).hasValidFacings();
    }

    private List<Object> handleDeploy(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = entityOrNull(message.entityId());
        if (entity == null || message.x() == null || message.y() == null) {
            return error("Deploy needs entityId, x and y");
        }
        Board board = game.getBoard(entity.getBoardId());
        Coords coords = new Coords(message.x(), message.y());
        if (board == null || !isDeployable(game, board, entity, coords)) {
            return error("That hex is not a legal deployment hex");
        }
        int facing = message.facing() == null ? entity.getFacing() : Math.floorMod(message.facing(), 6);
        AllowedDeploymentHelper helper = new AllowedDeploymentHelper(entity, coords, board, board.getHex(coords),
              game);
        List<ElevationOption> elevations = helper.findAllowedElevations();
        int elevation = elevations.isEmpty() ? 0 : elevations.getFirst().elevation();
        client.deploy(entity.getId(), coords, entity.getBoardId(), facing, elevation, List.of(), false);
        return List.of();
    }

    // -------------------------------------------------------------- movement

    private void handleMove(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = game.getEntityFromAllSources(message.entityId());
        if (entity == null) {
            LOGGER.warn("action.move for unknown entity {} ignored", message.entityId());
            return;
        }

        MovePath movePath = new MovePath(game, entity);
        for (String stepName : nullToEmpty(message.steps())) {
            try {
                movePath.addStep(MoveStepType.valueOf(stepName));
            } catch (IllegalArgumentException e) {
                LOGGER.warn("Unknown MoveStepType '{}' in action.move, skipped", stepName);
            }
        }
        movePath.clipToPossible();
        client.moveEntity(entity.getId(), movePath);
    }

    private static int maxMpFor(Entity entity, String mode) {
        return switch (mode) {
            case "JUMP" -> entity.getJumpMP();
            case "WALK" -> entity.getWalkMP();
            default -> entity.getRunMP();
        };
    }

    private static String normalizeMode(String mode) {
        if (mode == null) {
            return "RUN";
        }
        String upper = mode.toUpperCase();
        return switch (upper) {
            case "WALK", "RUN", "JUMP", "BACKWARDS" -> upper;
            default -> "RUN";
        };
    }

    private static MovePath basePath(Game game, Entity entity, String mode) {
        MovePath path = new MovePath(game, entity);
        if ("JUMP".equals(mode)) {
            path.addStep(MoveStepType.START_JUMP);
        } else if (entity.isProne()) {
            path.addStep(MoveStepType.GET_UP);
        }
        return path;
    }

    private static Map<Coords, MovePath> envelope(Game game, Entity entity, String mode) {
        MovePath start = basePath(game, entity, mode);
        MoveStepType stepType = "BACKWARDS".equals(mode) ? MoveStepType.BACKWARDS : MoveStepType.FORWARDS;
        ShortestPathFinder finder = ShortestPathFinder.newInstanceOfOneToAll(maxMpFor(entity, mode), stepType, game);
        finder.run(start);
        return finder.getAllComputedPaths();
    }

    private List<Object> handleMoveOptions(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = entityOrNull(message.entityId());
        if (entity == null || entity.getPosition() == null) {
            return error("Unknown or undeployed unit");
        }
        String mode = normalizeMode(message.mode());
        List<MoveHexDto> hexes = new ArrayList<>();
        if (maxMpFor(entity, mode) > 0 || entity.isProne()) {
            for (Map.Entry<Coords, MovePath> entry : envelope(game, entity, mode).entrySet()) {
                Coords coords = entry.getKey();
                MovePath path = entry.getValue();
                if (coords.equals(entity.getPosition()) && path.length() == 0) {
                    continue;
                }
                hexes.add(new MoveHexDto(coords.getX(), coords.getY(), path.getMpUsed()));
            }
        }
        return List.of(new MoveOptionsMessage(entity.getId(), mode, entity.getWalkMP(), entity.getRunMP(),
              entity.getJumpMP(), hexes));
    }

    /** Builds the full path (envelope path plus turns to the wanted facing), or null when unreachable. */
    private MovePath buildPath(Game game, Entity entity, String mode, Integer x, Integer y, Integer facing) {
        MovePath path;
        if (x == null || y == null) {
            path = new MovePath(game, entity);
        } else {
            Coords destination = new Coords(x, y);
            if (destination.equals(entity.getPosition())) {
                path = basePath(game, entity, mode);
            } else {
                MovePath found = envelope(game, entity, mode).get(destination);
                if (found == null) {
                    return null;
                }
                path = found.clone();
            }
        }
        if (facing != null) {
            int target = Math.floorMod(facing, 6);
            for (int guard = 0; guard < 6 && path.getFinalFacing() != target; guard++) {
                int diff = Math.floorMod(target - path.getFinalFacing(), 6);
                path.addStep(diff <= 3 ? MoveStepType.TURN_RIGHT : MoveStepType.TURN_LEFT);
            }
        }
        return path;
    }

    private List<Object> handleMovePreview(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = entityOrNull(message.entityId());
        if (entity == null || entity.getPosition() == null) {
            return error("Unknown or undeployed unit");
        }
        String mode = normalizeMode(message.mode());
        MovePath path = buildPath(game, entity, mode, message.x(), message.y(), message.facing());
        if (path == null) {
            return List.of(new MovePreviewMessage(entity.getId(), mode, false, 0, entity.getFacing(), List.of(),
                  "Hex is out of reach"));
        }
        boolean legal = path.isMoveLegal();
        return List.of(new MovePreviewMessage(entity.getId(), mode, legal, path.getMpUsed(),
              path.getFinalFacing(), pathCoords(path, entity), legal ? null : "Not enough movement"));
    }

    private static List<CoordDto> pathCoords(MovePath path, Entity entity) {
        List<CoordDto> coords = new ArrayList<>();
        Coords previous = entity.getPosition();
        if (previous != null) {
            coords.add(new CoordDto(previous.getX(), previous.getY()));
        }
        for (MoveStep step : path.getStepVector()) {
            Coords position = step.getPosition();
            if (position != null && !position.equals(previous)) {
                coords.add(new CoordDto(position.getX(), position.getY()));
                previous = position;
            }
        }
        return coords;
    }

    private List<Object> handleMoveTo(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = entityOrNull(message.entityId());
        if (entity == null) {
            return error("Unknown unit");
        }
        String mode = normalizeMode(message.mode());
        MovePath path = buildPath(game, entity, mode, message.x(), message.y(), message.facing());
        if (path == null) {
            return error("Hex is out of reach");
        }
        path.clipToPossible();
        client.moveEntity(entity.getId(), path);
        return List.of();
    }

    // ---------------------------------------------------------------- combat

    private void handleAttack(ActionMessage message) {
        if (message.entityId() == null) {
            LOGGER.warn("action.attack missing entityId, ignored: {}", message);
            return;
        }
        Entity attacker = entityOrNull(message.entityId());
        Vector<EntityAction> attacks = new Vector<>();
        if (attacker != null && message.targetId() != null) {
            for (Integer weaponId : nullToEmpty(message.weaponIds())) {
                attacks.add(buildWeaponAttack(attacker, message.targetId(), weaponId));
            }
        }
        client.sendAttackData(message.entityId(), attacks);
    }

    private static WeaponAttackAction buildWeaponAttack(Entity attacker, int targetId, int weaponNum) {
        WeaponAttackAction waa = new WeaponAttackAction(attacker.getId(), Targetable.TYPE_ENTITY, targetId,
              weaponNum);
        if (attacker.getEquipment(weaponNum) instanceof WeaponMounted weapon
              && weapon.getLinked() != null
              && weapon.getType().getAmmoType() != AmmoType.AmmoTypeEnum.NA
              && weapon.getLinkedAmmo() != null) {
            AmmoMounted ammo = weapon.getLinkedAmmo();
            waa.setAmmoId(ammo.getEquipmentNum());
            waa.setAmmoMunitionType(ammo.getType().getMunitionType());
            waa.setAmmoCarrier(ammo.getEntity().getId());
        }
        return waa;
    }

    private List<Object> handleAttackOptions(ActionMessage message, boolean physical) {
        Game game = client.getGame();
        Entity attacker = entityOrNull(message.entityId());
        Entity target = entityOrNull(message.targetId());
        if (attacker == null || target == null) {
            return error("Unknown attacker or target");
        }
        int range = attacker.getPosition() == null || target.getPosition() == null
              ? 0 : Compute.effectiveDistance(game, attacker, target);
        List<AttackOptionDto> options = new ArrayList<>();
        if (physical) {
            addPhysicalOptions(game, attacker, target, options);
        } else {
            for (WeaponMounted weapon : attacker.getWeaponList()) {
                if (weapon.isDestroyed() || weapon.isMissing()) {
                    continue;
                }
                options.add(weaponOption(game, attacker, target, weapon));
            }
        }
        return List.of(new AttackOptionsMessage(attacker.getId(), target.getId(), range, physical, options));
    }

    private static AttackOptionDto weaponOption(Game game, Entity attacker, Entity target, WeaponMounted weapon) {
        int damage = Math.max(0, weapon.getType().getDamage());
        int heat = Math.max(0, weapon.getType().getHeat());
        String name = weapon.getName() + " (" + attacker.getLocationAbbr(weapon.getLocation()) + ")";
        String key = Integer.toString(weapon.getEquipmentNum());
        if (weapon.isUsedThisRound()) {
            return new AttackOptionDto(key, name, null, 0, "Already fired", damage, heat, false);
        }
        try {
            ToHitData toHit = WeaponAttackAction.toHit(game, attacker.getId(), target, weapon.getEquipmentNum(),
                  false);
            return toOption(key, name, toHit, damage, heat);
        } catch (RuntimeException e) {
            LOGGER.warn(e, "to-hit calculation failed for {}", weapon.getName());
            return new AttackOptionDto(key, name, null, 0, "Cannot be calculated", damage, heat, false);
        }
    }

    private static AttackOptionDto toOption(String key, String name, ToHitData toHit, int damage, int heat) {
        if (toHit.cannotSucceed()) {
            return new AttackOptionDto(key, name, null, 0, toHit.getDesc(), damage, heat, false);
        }
        int value = toHit.getValue();
        int probability = (int) Math.round(Compute.oddsAbove(value));
        return new AttackOptionDto(key, name, value, probability, toHit.getDesc(), damage, heat, true);
    }

    private static void addPhysicalOptions(Game game, Entity attacker, Entity target, List<AttackOptionDto> out) {
        if (!(attacker instanceof Mek)) {
            return;
        }
        boolean infantry = target.isInfantry();
        record Candidate(String key, String name, int damage, java.util.function.Supplier<ToHitData> toHit) {
        }
        List<Candidate> candidates = List.of(
              new Candidate("PUNCH_LEFT", "Punch (left arm)",
                    PunchAttackAction.getDamageFor(attacker, PunchAttackAction.LEFT, infantry, false),
                    () -> PunchAttackAction.toHit(game, attacker.getId(), target, PunchAttackAction.LEFT, false)),
              new Candidate("PUNCH_RIGHT", "Punch (right arm)",
                    PunchAttackAction.getDamageFor(attacker, PunchAttackAction.RIGHT, infantry, false),
                    () -> PunchAttackAction.toHit(game, attacker.getId(), target, PunchAttackAction.RIGHT, false)),
              new Candidate("KICK", "Kick",
                    KickAttackAction.getDamageFor(attacker, KickAttackAction.RIGHT, infantry),
                    () -> KickAttackAction.toHit(game, attacker.getId(), target, KickAttackAction.RIGHT)));
        for (Candidate candidate : candidates) {
            try {
                out.add(toOption(candidate.key(), candidate.name(), candidate.toHit().get(), candidate.damage(), 0));
            } catch (RuntimeException e) {
                out.add(new AttackOptionDto(candidate.key(), candidate.name(), null, 0, "Not possible",
                      candidate.damage(), 0, false));
            }
        }
    }

    private List<Object> handlePhysical(ActionMessage message) {
        if (message.entityId() == null) {
            return error("Missing entityId");
        }
        Vector<EntityAction> attacks = new Vector<>();
        if (message.targetId() != null && message.kind() != null) {
            int id = message.entityId();
            int target = message.targetId();
            switch (message.kind()) {
                case "PUNCH_LEFT" -> attacks.add(new PunchAttackAction(id, target, PunchAttackAction.LEFT));
                case "PUNCH_RIGHT" -> attacks.add(new PunchAttackAction(id, target, PunchAttackAction.RIGHT));
                case "KICK" -> attacks.add(new KickAttackAction(id, target, KickAttackAction.RIGHT));
                default -> {
                    return error("Unknown physical attack " + message.kind());
                }
            }
        }
        client.sendAttackData(message.entityId(), attacks);
        return List.of();
    }

    // ----------------------------------------------------------------- misc

    private void handleEndPhase(ActionMessage message) {
        boolean done = message.done() == null || message.done();
        client.sendDone(done);
    }

    private void handleChat(ActionMessage message) {
        if (message.text() != null && !message.text().isBlank()) {
            client.sendChat(message.text());
        }
    }

    private Entity entityOrNull(Integer id) {
        return id == null ? null : client.getGame().getEntityFromAllSources(id);
    }

    /** The MegaMek client (human or bot) that owns {@code playerId}, or null if it isn't ours. */
    private Client clientOwning(int playerId) {
        if (playerId == client.getLocalPlayerNumber()) {
            return client;
        }
        for (Princess princess : botManager.all()) {
            if (princess.getLocalPlayerNumber() == playerId) {
                return princess;
            }
        }
        return null;
    }

    private Entity loadEntityOrWarn(String unitRef) {
        if (unitRef == null || unitRef.isBlank()) {
            LOGGER.warn("Action missing unitRef, ignored");
            return null;
        }
        MekSummary summary = MekSummaryCache.getInstance().getMek(unitRef);
        if (summary == null) {
            LOGGER.warn("Unknown unitRef '{}', ignored", unitRef);
            return null;
        }
        Entity entity = summary.loadEntity();
        if (entity == null) {
            LOGGER.warn("Failed to load entity for '{}', ignored", unitRef);
            return null;
        }
        return entity;
    }

    private static <T> List<T> nullToEmpty(List<T> list) {
        return list == null ? List.of() : list;
    }
}
