package megamekmobile.bridge;

import megamek.common.loaders.MekSummaryCache;
import megamek.logging.MMLogger;

import megamekmobile.bridge.dto.ConnectionStatusMessage;

/**
 * Entry point: connects one {@link MegaMekBridgeClient} to a MegaMek server and starts the
 * {@link BridgeServer} that mirrors its game state to mobile clients (see CLAUDE.md architecture
 * diagram and docs/decisions.md #4 for why this is one process per player slot).
 */
public final class BridgeApplication {

    private static final MMLogger LOGGER = MMLogger.create(BridgeApplication.class);

    private BridgeApplication() {
    }

    public static void main(String[] args) {
        BridgeConfig config = BridgeConfig.fromEnvAndArgs(args);
        LOGGER.info(
              "Starting bridge: player='{}' -> megamek {}:{}, mobile API on port {}",
              config.playerName(),
              config.megamekHost(),
              config.megamekPort(),
              config.bridgePort());

        // Kicks off MekSummaryCache's background load now, so it's likely already warm by the time a
        // mobile client opens the mech catalog (getAllMeks()/getMek() block until loading finishes).
        MekSummaryCache.getInstance();

        MegaMekBridgeClient client = new MegaMekBridgeClient(
              config.playerName(),
              config.megamekHost(),
              config.megamekPort());
        BotManager botManager = new BotManager(config.megamekHost(), config.megamekPort());
        BridgeSession session = new BridgeSession(client, botManager, config.serverPassword());
        BridgeServer server = new BridgeServer(session);
        session.attach(server);

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            session.shutdown();
            server.stop();
        }));

        server.start(config.bridgePort());

        if (!client.connect()) {
            LOGGER.error("Could not connect to MegaMek server at {}:{}",
                  config.megamekHost(), config.megamekPort());
            server.broadcast(new ConnectionStatusMessage("error", "Could not reach MegaMek server"));
            return;
        }
        server.broadcast(new ConnectionStatusMessage("connected", null));
    }
}
