package megamekmobile.bridge.dto;

import java.util.List;

/**
 * Reply to {@code action.move_options}: the movement envelope for one movement mode ("WALK", "RUN",
 * "JUMP" or "BACKWARDS") plus the unit's movement point budgets.
 */
public record MoveOptionsMessage(
      String type,
      int schemaVersion,
      int entityId,
      String mode,
      int walkMp,
      int runMp,
      int jumpMp,
      List<MoveHexDto> hexes) {

    public static final String TYPE = "state.move_options";
    public static final int SCHEMA_VERSION = 1;

    public MoveOptionsMessage(int entityId, String mode, int walkMp, int runMp, int jumpMp,
          List<MoveHexDto> hexes) {
        this(TYPE, SCHEMA_VERSION, entityId, mode, walkMp, runMp, jumpMp, hexes);
    }
}
