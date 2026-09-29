package megamekmobile.bridge.dto;

import java.util.List;

/**
 * Reply to one client's {@code action.unit_catalog_search} - sent only to that client, never
 * broadcast (see {@code BridgeServer.handleIncoming}). {@code totalMatches} is the count before
 * {@code units} was capped, so the mobile UI can show e.g. "50 of 8214 - refine your search".
 */
public record UnitCatalogMessage(String type, int schemaVersion, List<UnitSummaryDto> units, int totalMatches) {

    public static final String TYPE = "state.unit_catalog";
    public static final int SCHEMA_VERSION = 1;

    public UnitCatalogMessage(List<UnitSummaryDto> units, int totalMatches) {
        this(TYPE, SCHEMA_VERSION, units, totalMatches);
    }
}
