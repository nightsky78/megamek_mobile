package megamekmobile.bridge;

import megamek.common.event.GameListenerAdapter;
import megamek.common.event.GameSettingsChangeEvent;
import megamek.common.event.board.GameBoardChangeEvent;
import megamek.common.event.board.GameBoardNewEvent;
import megamek.common.event.entity.GameEntityChangeEvent;
import megamek.common.event.entity.GameEntityNewEvent;
import megamek.common.event.entity.GameEntityRemoveEvent;
import megamek.common.event.player.GamePlayerChangeEvent;
import megamek.common.event.player.GamePlayerChatEvent;
import megamek.common.loaders.MekSummaryCache;
import megamek.logging.MMLogger;

import megamekmobile.bridge.dto.ChatMessage;
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

        BridgeServer server = new BridgeServer(client, botManager);
        registerGameListeners(client, server);

        server.start(config.bridgePort());

        if (!client.connect()) {
            LOGGER.error("Could not connect to MegaMek server at {}:{}",
                  config.megamekHost(), config.megamekPort());
            server.broadcast(new ConnectionStatusMessage("error", "Could not reach MegaMek server"));
            return;
        }
        server.broadcast(new ConnectionStatusMessage("connected", null));

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            botManager.shutdown();
            client.die();
            server.stop();
        }));
    }

    /**
     * Rebuilds and re-broadcasts the full snapshot on every structural change. See CLAUDE.md
     * "Bekannter Stand" for the documented follow-up of diffing instead of resending everything.
     */
    private static void registerGameListeners(MegaMekBridgeClient client, BridgeServer server) {
        client.getGame().addGameListener(new GameListenerAdapter() {

            @Override
            public void gamePhaseChange(megamek.common.event.GamePhaseChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameTurnChange(megamek.common.event.GameTurnChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameEntityNew(GameEntityNewEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameEntityRemove(GameEntityRemoveEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameEntityChange(GameEntityChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gamePlayerChange(GamePlayerChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameBoardNew(GameBoardNewEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameBoardChanged(GameBoardChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gameSettingsChange(GameSettingsChangeEvent e) {
                server.broadcastSnapshot();
            }

            @Override
            public void gamePlayerChat(GamePlayerChatEvent e) {
                server.broadcast(new ChatMessage(e.getMessage()));
            }
        });
    }
}
