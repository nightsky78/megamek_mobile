package megamekmobile.bridge.dto;

/** One chunk of the server's game report (what fired, what hit, what died) as plain text. */
public record ReportMessage(String type, int schemaVersion, int round, String phase, String text) {

    public static final String TYPE = "state.report";
    public static final int SCHEMA_VERSION = 1;

    public ReportMessage(int round, String phase, String text) {
        this(TYPE, SCHEMA_VERSION, round, phase, text);
    }
}
