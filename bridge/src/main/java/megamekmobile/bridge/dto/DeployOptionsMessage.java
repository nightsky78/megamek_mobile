package megamekmobile.bridge.dto;

import java.util.List;

/** Reply to {@code action.deploy_options}: every hex the entity may legally be placed in. */
public record DeployOptionsMessage(String type, int schemaVersion, int entityId, List<CoordDto> hexes) {

    public static final String TYPE = "state.deploy_options";
    public static final int SCHEMA_VERSION = 1;

    public DeployOptionsMessage(int entityId, List<CoordDto> hexes) {
        this(TYPE, SCHEMA_VERSION, entityId, hexes);
    }
}
