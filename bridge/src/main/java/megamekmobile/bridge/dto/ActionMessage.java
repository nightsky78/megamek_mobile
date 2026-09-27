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
 * </ul>
 */
public record ActionMessage(
      String type,
      Integer entityId,
      List<String> steps,
      Integer targetId,
      List<Integer> weaponIds,
      Boolean done,
      String text) {

    public static final String MOVE = "action.move";
    public static final String ATTACK = "action.attack";
    public static final String END_PHASE = "action.end_phase";
    public static final String CHAT = "action.chat";
}
