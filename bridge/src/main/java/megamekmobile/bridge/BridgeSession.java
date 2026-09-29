package megamekmobile.bridge;

import java.util.ArrayList;
import java.util.List;
import java.util.Vector;

import megamek.common.actions.EntityAction;
import megamek.common.actions.WeaponAttackAction;
import megamek.common.compute.Compute;
import megamek.common.enums.GamePhase;
import megamek.common.event.GameCFREvent;
import megamek.common.event.GameListenerAdapter;
import megamek.common.event.GamePhaseChangeEvent;
import megamek.common.event.GameSettingsChangeEvent;
import megamek.common.event.GameTurnChangeEvent;
import megamek.common.event.board.GameBoardChangeEvent;
import megamek.common.event.board.GameBoardNewEvent;
import megamek.common.event.entity.GameEntityChangeEvent;
import megamek.common.event.entity.GameEntityNewEvent;
import megamek.common.event.entity.GameEntityRemoveEvent;
import megamek.common.event.player.GamePlayerChangeEvent;
import megamek.common.event.player.GamePlayerChatEvent;
import megamek.common.game.Game;
import megamek.logging.MMLogger;

import megamekmobile.bridge.dto.ChatMessage;
import megamekmobile.bridge.dto.ReportMessage;
import megamekmobile.bridge.mapping.ActionHandler;
import megamekmobile.bridge.mapping.GameStateMapper;

/**
 * Everything that belongs to one player slot on the MegaMek server: the human client, its bots, the
 * action handler and the game report log. {@link BridgeServer} talks to exactly one session, which is
 * the seam for hosting several sessions per bridge process later (see docs/roadmap.md, Phase 7).
 *
 * <p>The session also does what MegaMek's Swing UI does implicitly and a phone UI must not have to:
 * answer client feedback requests (AMS assignment, domino effect, ...) that would otherwise block the
 * server, skip phases the mobile app has no UI for, and keep the game report text.
 */
public final class BridgeSession {

    private static final MMLogger LOGGER = MMLogger.create(BridgeSession.class);
    private static final int MAX_LOG_ENTRIES = 400;

    private final MegaMekBridgeClient client;
    private final BotManager botManager;
    private final ActionHandler actionHandler;
    private final List<ReportMessage> reportLog = new ArrayList<>();
    private BridgeServer server;
    private int reportRound = -1;
    private int reportCount;

    public BridgeSession(MegaMekBridgeClient client, BotManager botManager, String serverPassword) {
        this.client = client;
        this.botManager = botManager;
        this.actionHandler = new ActionHandler(client, botManager, serverPassword);
        client.setSendDoneOnVictoryAutomatically(false);
    }

    public MegaMekBridgeClient client() {
        return client;
    }

    public BotManager botManager() {
        return botManager;
    }

    public ActionHandler actionHandler() {
        return actionHandler;
    }

    public Object snapshot() {
        return GameStateMapper.snapshot(client.getGame(), client.getLocalPlayerNumber());
    }

    /** Report entries a newly connected mobile client should see to catch up. */
    public synchronized List<ReportMessage> reportLog() {
        return new ArrayList<>(reportLog);
    }

    public void shutdown() {
        botManager.shutdown();
        client.die();
    }

    public void attach(BridgeServer bridgeServer) {
        this.server = bridgeServer;
        client.getGame().addGameListener(new GameListenerAdapter() {

            @Override
            public void gamePhaseChange(GamePhaseChangeEvent e) {
                onPhaseChange(e.getNewPhase());
            }

            @Override
            public void gameTurnChange(GameTurnChangeEvent e) {
                server.broadcastSnapshot();
                autoSkipIfNeeded();
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

            @Override
            public void gameClientFeedbackRequest(GameCFREvent e) {
                answerFeedbackRequest(e);
            }
        });
    }

    private void onPhaseChange(GamePhase phase) {
        if (phase == GamePhase.LOUNGE) {
            botManager.purgeDisconnected();
        }
        collectReports(phase);
        server.broadcastSnapshot();
        autoSkipIfNeeded();
    }

    // ------------------------------------------------------------------ reports

    private synchronized void collectReports(GamePhase phase) {
        Game game = client.getGame();
        int round = game.getCurrentRound();
        if (phase == GamePhase.LOUNGE) {
            reportLog.clear();
            reportRound = -1;
            reportCount = 0;
            return;
        }
        if (round != reportRound) {
            reportRound = round;
            reportCount = 0;
        }
        List<megamek.common.Report> reports;
        try {
            reports = game.getReports(round);
        } catch (RuntimeException e) {
            return;
        }
        if (reports == null || reports.size() <= reportCount) {
            return;
        }
        StringBuilder text = new StringBuilder();
        for (int i = reportCount; i < reports.size(); i++) {
            String line = ReportText.plain(reports.get(i).text());
            if (!line.isBlank()) {
                text.append(line).append('\n');
            }
        }
        reportCount = reports.size();
        if (text.isEmpty()) {
            return;
        }
        ReportMessage message = new ReportMessage(round, phase.name(), text.toString().stripTrailing());
        reportLog.add(message);
        while (reportLog.size() > MAX_LOG_ENTRIES) {
            reportLog.removeFirst();
        }
        server.broadcast(message);
    }

    // ---------------------------------------------------------- feedback requests

    private void answerFeedbackRequest(GameCFREvent e) {
        try {
            switch (e.getCFRType()) {
                case CFR_DOMINO_EFFECT -> client.sendDominoCFRResponse(null);
                case CFR_AMS_ASSIGN -> {
                    int index = indexOfBest(e.getWAAs());
                    client.sendAMSAssignCFRResponse(new int[] { index });
                }
                case CFR_APDS_ASSIGN -> client.sendAPDSAssignCFRResponse(indexOfBest(e.getWAAs()));
                case CFR_HIDDEN_PBS -> client.sendHiddenPBSCFRResponse(null);
                case CFR_TELEGUIDED_TARGET -> client.sendTelemissileTargetCFRResponse(0);
                case CFR_TAG_TARGET -> client.sendTAGTargetCFRResponse(0);
                default -> LOGGER.warn("Unhandled client feedback request {}", e.getCFRType());
            }
        } catch (RuntimeException ex) {
            LOGGER.error(ex, "Failed to answer client feedback request {}", e.getCFRType());
        }
    }

    private int indexOfBest(List<WeaponAttackAction> waas) {
        if (waas == null || waas.isEmpty()) {
            return 0;
        }
        WeaponAttackAction best = Compute.getHighestExpectedDamage(client.getGame(), waas, true);
        int index = waas.indexOf(best);
        return Math.max(index, 0);
    }

    // ------------------------------------------------------------- phase skipping

    /** Phases the mobile app has no UI for are answered with "nothing to do" so the game keeps moving. */
    private void autoSkipIfNeeded() {
        Game game = client.getGame();
        GamePhase phase = game.getPhase();
        if (phase == null || !client.isMyTurn()) {
            return;
        }
        try {
            switch (phase) {
                case TARGETING, OFFBOARD -> {
                    List<Integer> actable = GameStateMapper.actableEntityIds(game, client.getLocalPlayerNumber());
                    if (actable.isEmpty()) {
                        client.sendDone(true);
                    } else {
                        client.sendAttackData(actable.getFirst(), new Vector<EntityAction>());
                    }
                }
                case PREMOVEMENT, PRE_FIRING -> client.sendDone(true);
                default -> {
                }
            }
        } catch (RuntimeException ex) {
            LOGGER.error(ex, "Auto-skip of phase {} failed", phase);
        }
    }
}
