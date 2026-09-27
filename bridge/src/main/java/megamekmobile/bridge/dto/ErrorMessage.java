package megamekmobile.bridge.dto;

public record ErrorMessage(String type, int schemaVersion, String message) {

    public static final String TYPE = "error";
    public static final int SCHEMA_VERSION = 1;

    public ErrorMessage(String message) {
        this(TYPE, SCHEMA_VERSION, message);
    }
}
