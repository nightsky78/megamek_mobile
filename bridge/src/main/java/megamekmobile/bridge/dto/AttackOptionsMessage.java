package megamekmobile.bridge.dto;

import java.util.List;

/** Reply to {@code action.attack_options}/{@code action.physical_options}. */
public record AttackOptionsMessage(
      String type,
      int schemaVersion,
      int entityId,
      int targetId,
      int range,
      boolean physical,
      List<AttackOptionDto> options) {

    public static final String TYPE = "state.attack_options";
    public static final int SCHEMA_VERSION = 1;

    public AttackOptionsMessage(int entityId, int targetId, int range, boolean physical,
          List<AttackOptionDto> options) {
        this(TYPE, SCHEMA_VERSION, entityId, targetId, range, physical, options);
    }
}
