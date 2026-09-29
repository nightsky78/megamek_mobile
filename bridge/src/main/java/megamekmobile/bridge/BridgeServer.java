package megamekmobile.bridge;

import java.time.Duration;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import com.fasterxml.jackson.databind.ObjectMapper;

import io.javalin.Javalin;
import io.javalin.websocket.WsContext;
import io.javalin.websocket.WsMessageContext;

import megamek.common.loaders.MekSummary;
import megamek.common.loaders.MekSummaryCache;
import megamek.logging.MMLogger;

import megamekmobile.bridge.dto.ActionMessage;
import megamekmobile.bridge.dto.ErrorMessage;
import megamekmobile.bridge.mapping.ActionHandler;
import megamekmobile.bridge.mapping.GameStateMapper;
import megamekmobile.bridge.mapping.UnitCatalogMapper;

/**
 * The mobile-facing side of the bridge: one WebSocket endpoint ({@code /ws}) that every connected
 * mobile client uses both to receive game-state pushes and to send actions, plus a plain REST
 * {@code /health} endpoint (see docs/decisions.md #8).
 */
public class BridgeServer {

    private static final MMLogger LOGGER = MMLogger.create(BridgeServer.class);

    private final MegaMekBridgeClient client;
    private final ActionHandler actionHandler;
    private final ObjectMapper mapper = new ObjectMapper();
    private final Set<WsContext> sessions = ConcurrentHashMap.newKeySet();
    private Javalin app;

    public BridgeServer(MegaMekBridgeClient client, BotManager botManager) {
        this.client = client;
        this.actionHandler = new ActionHandler(client, botManager);
    }

    public void start(int port) {
        // Default Jetty WS idle timeout (30s) is far shorter than a human can sit in the
        // lobby/game reading state before sending a chat message or action; without this,
        // the socket silently dies mid-session and the app has no reconnect handling (see
        // mobile/README.md "Known limitations"), so every subsequent action is a no-op.
        app = Javalin.create(config -> config.jetty.modifyWebSocketServletFactory(
              factory -> factory.setIdleTimeout(Duration.ofMinutes(30))));
        app.get("/health", ctx -> ctx.result("ok"));
        app.ws("/ws", ws -> {
            ws.onConnect(ctx -> {
                sessions.add(ctx);
                LOGGER.info("Mobile client connected ({} total)", sessions.size());
                sendSnapshot(ctx);
            });
            ws.onClose(ctx -> {
                sessions.remove(ctx);
                LOGGER.info("Mobile client disconnected ({} remaining)", sessions.size());
            });
            ws.onMessage(this::handleIncoming);
            ws.onError(ctx -> LOGGER.warn(ctx.error(), "WebSocket error"));
        });
        app.start(port);
        LOGGER.info("Bridge WebSocket/REST API listening on port {}", port);
    }

    public void stop() {
        if (app != null) {
            app.stop();
        }
    }

    private void handleIncoming(WsMessageContext ctx) {
        try {
            ActionMessage message = mapper.readValue(ctx.message(), ActionMessage.class);
            if (ActionMessage.UNIT_CATALOG_SEARCH.equals(message.type())) {
                // Answered per-client rather than broadcast: this only touches MekSummaryCache, never
                // Game/Client, so it can never arrive via the normal GameListener -> broadcastSnapshot
                // path the rest of the bridge relies on.
                MekSummary[] allUnits = MekSummaryCache.getInstance().getAllMeks();
                send(ctx, UnitCatalogMapper.search(allUnits, message));
                return;
            }
            actionHandler.handle(message);
        } catch (Exception e) {
            LOGGER.warn(e, "Failed to handle incoming action message");
            send(ctx, new ErrorMessage("Could not process message: " + e.getMessage()));
        }
    }

    private void sendSnapshot(WsContext ctx) {
        send(ctx, GameStateMapper.snapshot(client.getGame(), client.getLocalPlayerNumber()));
    }

    /** Rebuilds the full snapshot from the live game state and pushes it to every connected client. */
    public void broadcastSnapshot() {
        broadcast(GameStateMapper.snapshot(client.getGame(), client.getLocalPlayerNumber()));
    }

    public void broadcast(Object message) {
        String json = toJson(message);
        if (json == null) {
            return;
        }
        for (WsContext ctx : sessions) {
            ctx.send(json);
        }
    }

    private void send(WsContext ctx, Object message) {
        String json = toJson(message);
        if (json != null) {
            ctx.send(json);
        }
    }

    private String toJson(Object message) {
        try {
            return mapper.writeValueAsString(message);
        } catch (Exception e) {
            LOGGER.error(e, "Failed to serialize outgoing message");
            return null;
        }
    }
}
