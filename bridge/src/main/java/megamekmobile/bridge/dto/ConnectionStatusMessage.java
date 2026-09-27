package megamekmobile.bridge.dto;

public record ConnectionStatusMessage(String type, int schemaVersion, String status, String detail) {

    public static final String TYPE = "connection.status";
    public static final int SCHEMA_VERSION = 1;

    public ConnectionStatusMessage(String status, String detail) {
        this(TYPE, SCHEMA_VERSION, status, detail);
    }
}
