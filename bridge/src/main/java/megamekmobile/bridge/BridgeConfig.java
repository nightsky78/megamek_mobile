package megamekmobile.bridge;

/**
 * Bridge configuration, read from environment variables with command-line overrides
 * (see CLAUDE.md "Lokal starten"). One bridge process = one MegaMek player slot
 * (see docs/decisions.md #4).
 */
public record BridgeConfig(String megamekHost, int megamekPort, String playerName, int bridgePort, String serverPassword) {

    public static BridgeConfig fromEnvAndArgs(String[] args) {
        String host = env("MEGAMEK_HOST", "localhost");
        int port = Integer.parseInt(env("MEGAMEK_PORT", "2346"));
        String player = env("PLAYER_NAME", "BridgePlayer");
        int bridgePort = Integer.parseInt(env("BRIDGE_PORT", "8080"));
        String serverPassword = env("SERVER_PASSWORD", "");

        for (String arg : args) {
            if (arg.startsWith("--host=")) {
                host = arg.substring("--host=".length());
            } else if (arg.startsWith("--port=")) {
                port = Integer.parseInt(arg.substring("--port=".length()));
            } else if (arg.startsWith("--player=")) {
                player = arg.substring("--player=".length());
            } else if (arg.startsWith("--bridge-port=")) {
                bridgePort = Integer.parseInt(arg.substring("--bridge-port=".length()));
            } else if (arg.startsWith("--server-password=")) {
                serverPassword = arg.substring("--server-password=".length());
            }
        }
        return new BridgeConfig(host, port, player, bridgePort, serverPassword);
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return (value == null || value.isBlank()) ? fallback : value;
    }
}
