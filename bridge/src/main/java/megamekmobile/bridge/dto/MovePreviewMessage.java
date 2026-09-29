package megamekmobile.bridge.dto;

import java.util.List;

/** Reply to {@code action.move_preview}: the path the bridge would send for a given destination. */
public record MovePreviewMessage(
      String type,
      int schemaVersion,
      int entityId,
      String mode,
      boolean legal,
      int mpUsed,
      int facing,
      List<CoordDto> path,
      String message) {

    public static final String TYPE = "state.move_preview";
    public static final int SCHEMA_VERSION = 1;

    public MovePreviewMessage(int entityId, String mode, boolean legal, int mpUsed, int facing,
          List<CoordDto> path, String message) {
        this(TYPE, SCHEMA_VERSION, entityId, mode, legal, mpUsed, facing, path, message);
    }
}
