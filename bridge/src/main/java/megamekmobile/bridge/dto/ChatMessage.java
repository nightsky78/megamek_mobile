package megamekmobile.bridge.dto;

public record ChatMessage(String type, int schemaVersion, String text) {

    public static final String TYPE = "chat.message";
    public static final int SCHEMA_VERSION = 1;

    public ChatMessage(String text) {
        this(TYPE, SCHEMA_VERSION, text);
    }
}
