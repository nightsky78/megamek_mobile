package megamekmobile.bridge.dto;

import java.util.List;

/**
 * Envelope for every JSON message a mobile client sends to the bridge. Which fields are populated
 * depends on {@code type}; see {@code docs/protocol-notes.md} for the full mapping to MegaMek
 * {@code Client} calls:
 *
 * <ul>
 *   <li>{@code action.move}: {@code entityId}, {@code steps} - each one the name of a
 *       {@code megamek.common.enums.MoveStepType} constant, e.g. "FORWARDS", "BACKWARDS",
 *       "TURN_LEFT", "TURN_RIGHT", "LATERAL_LEFT", "LATERAL_RIGHT"</li>
 *   <li>{@code action.attack}: {@code entityId}, {@code targetId}, {@code weaponIds}</li>
 *   <li>{@code action.end_phase}: {@code done} (defaults to {@code true} when omitted)</li>
 *   <li>{@code action.chat}: {@code text}</li>
 *   <li>{@code action.add_unit}: {@code unitRef} - a {@code MekSummary.getName()} value, as
 *       returned by {@code action.unit_catalog_search}</li>
 *   <li>{@code action.add_bot}: {@code botName}, optional {@code difficulty} (EASY/NORMAL/HARD/DEFAULT)</li>
 *   <li>{@code action.add_bot_unit}: {@code botName}, {@code unitRef}</li>
 *   <li>{@code action.select_board}: {@code boardNames} (exactly one entry for the MVP)</li>
 *   <li>{@code action.start_game}: no fields</li>
 *   <li>{@code action.unit_catalog_search}: {@code text} (substring match, optional),
 *       {@code unitType}, {@code clanOnly}, {@code minTons}, {@code maxTons}, {@code limit},
 *       {@code minYear}, {@code maxYear}, {@code minBv}, {@code maxBv}, {@code techBase} - all
 *       optional filters, answered with a {@code state.unit_catalog} reply to the requesting client
 *       only (not broadcast)</li>
 *   <li>{@code action.deploy_options}: {@code entityId} - replies {@code state.deploy_options}</li>
 *   <li>{@code action.deploy}: {@code entityId}, {@code x}, {@code y}, {@code facing}</li>
 *   <li>{@code action.move_options}: {@code entityId}, {@code mode} (WALK/RUN/JUMP/BACKWARDS) -
 *       replies {@code state.move_options}</li>
 *   <li>{@code action.move_preview}: {@code entityId}, {@code mode}, {@code x}, {@code y},
 *       optional {@code facing} - replies {@code state.move_preview}</li>
 *   <li>{@code action.move_to}: same fields as move_preview, actually sends the move; a missing
 *       {@code x}/{@code y} stands still (or only turns when {@code facing} is set)</li>
 *   <li>{@code action.attack_options}/{@code action.physical_options}: {@code entityId},
 *       {@code targetId} - reply {@code state.attack_options}</li>
 *   <li>{@code action.physical}: {@code entityId}, {@code targetId}, {@code kind} (PUNCH_LEFT,
 *       PUNCH_RIGHT, KICK); a missing {@code targetId} skips the physical attack</li>
 *   <li>{@code action.remove_unit}: {@code entityId} (the bridge resolves the owning client)</li>
 *   <li>{@code action.set_pilot}: {@code entityId}, {@code gunnery}, {@code piloting}</li>
 *   <li>{@code action.set_team}: {@code team}, optional {@code botName} (defaults to the human)</li>
 *   <li>{@code action.new_game}: leaves the victory screen (server resets to the lobby)</li>
 * </ul>
 */
public record ActionMessage(
      String type,
      Integer entityId,
      List<String> steps,
      Integer targetId,
      List<Integer> weaponIds,
      Boolean done,
      String text,
      String unitRef,
      String botName,
      List<String> boardNames,
      String unitType,
      Boolean clanOnly,
      Double minTons,
      Double maxTons,
      Integer limit,
      Integer x,
      Integer y,
      Integer facing,
      String mode,
      String kind,
      Integer gunnery,
      Integer piloting,
      Integer team,
      String difficulty,
      Integer minYear,
      Integer maxYear,
      Integer minBv,
      Integer maxBv,
      String techBase) {

    public static final String MOVE = "action.move";
    public static final String ATTACK = "action.attack";
    public static final String END_PHASE = "action.end_phase";
    public static final String CHAT = "action.chat";
    public static final String ADD_UNIT = "action.add_unit";
    public static final String ADD_BOT = "action.add_bot";
    public static final String ADD_BOT_UNIT = "action.add_bot_unit";
    public static final String SELECT_BOARD = "action.select_board";
    public static final String START_GAME = "action.start_game";
    public static final String UNIT_CATALOG_SEARCH = "action.unit_catalog_search";
    public static final String PING = "action.ping";
    public static final String DEPLOY_OPTIONS = "action.deploy_options";
    public static final String DEPLOY = "action.deploy";
    public static final String MOVE_OPTIONS = "action.move_options";
    public static final String MOVE_PREVIEW = "action.move_preview";
    public static final String MOVE_TO = "action.move_to";
    public static final String ATTACK_OPTIONS = "action.attack_options";
    public static final String PHYSICAL_OPTIONS = "action.physical_options";
    public static final String PHYSICAL = "action.physical";
    public static final String REMOVE_UNIT = "action.remove_unit";
    public static final String SET_PILOT = "action.set_pilot";
    public static final String SET_TEAM = "action.set_team";
    public static final String NEW_GAME = "action.new_game";
}
