package megamekmobile.bridge;

import java.util.Collection;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import megamek.client.bot.princess.BehaviorSettingsFactory;
import megamek.client.bot.princess.Princess;
import megamek.logging.MMLogger;

/**
 * Owns the bridge's Princess AI opponents. Each bot is a second, independent connection to the same
 * MegaMek server (see docs/protocol-notes.md) - not something the human player's {@code Client}
 * manages - so {@link megamekmobile.bridge.mapping.ActionHandler} routes bot-targeted actions here to
 * reach the right {@code Client} instance.
 */
public final class BotManager {

    private static final MMLogger LOGGER = MMLogger.create(BotManager.class);

    private final String megamekHost;
    private final int megamekPort;
    private final Map<String, Princess> bots = new ConcurrentHashMap<>();

    public BotManager(String megamekHost, int megamekPort) {
        this.megamekHost = megamekHost;
        this.megamekPort = megamekPort;
    }

    /**
     * Connects a new bot named {@code botName}, or returns the existing one if that name is already
     * tracked (idempotent, since a mobile client retrying a dropped "add bot" request should not spawn
     * a second bot). Returns {@code null} if the connection attempt itself fails.
     */
    public Princess addBot(String botName) {
        Princess existing = bots.get(botName);
        if (existing != null) {
            LOGGER.warn("Bot '{}' already exists, ignoring", botName);
            return existing;
        }

        Princess princess = new Princess(botName, megamekHost, megamekPort);
        princess.setBehaviorSettings(BehaviorSettingsFactory.getInstance().DEFAULT_BEHAVIOR);
        princess.startPrecognition();
        if (!princess.connect()) {
            LOGGER.error("Bot '{}' could not connect to {}:{}", botName, megamekHost, megamekPort);
            return null;
        }

        bots.put(botName, princess);
        return princess;
    }

    public Princess get(String botName) {
        return bots.get(botName);
    }

    public Collection<Princess> all() {
        return bots.values();
    }

    public void shutdown() {
        bots.values().forEach(Princess::die);
        bots.clear();
    }
}
