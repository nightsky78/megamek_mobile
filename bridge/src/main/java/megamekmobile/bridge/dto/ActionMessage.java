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
 *   <li>{@code action.add_bot}: {@code botName}</li>
 *   <li>{@code action.add_bot_unit}: {@code botName}, {@code unitRef}</li>
 *   <li>{@code action.select_board}: {@code boardNames} (exactly one entry for the MVP)</li>
 *   <li>{@code action.start_game}: no fields</li>
 *   <li>{@code action.unit_catalog_search}: {@code text} (substring match, optional),
 *       {@code unitType}, {@code clanOnly}, {@code minTons}, {@code maxTons}, {@code limit} -
 *       all optional filters, answered with a {@code state.unit_catalog} reply to the
 *       requesting client only (not broadcast)</li>
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
      Integer limit) {

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
}
