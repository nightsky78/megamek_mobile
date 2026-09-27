package megamekmobile.bridge.mapping;

import java.util.List;
import java.util.Vector;

import megamek.client.Client;
import megamek.common.actions.EntityAction;
import megamek.common.actions.WeaponAttackAction;
import megamek.common.enums.MoveStepType;
import megamek.common.game.Game;
import megamek.common.moves.MovePath;
import megamek.common.units.Entity;
import megamek.logging.MMLogger;

import megamekmobile.bridge.dto.ActionMessage;

/**
 * Turns a mobile client's {@link ActionMessage} into the matching call on MegaMek's own {@link Client},
 * exactly the way the Swing UI would (see {@code docs/protocol-notes.md} for the full table). Kept
 * independent of the WebSocket layer so it can be unit-tested without a live connection - though a
 * useful test here needs a real, connected {@code Client} and {@code Game}, which is Bridge-integration
 * rather than pure-unit territory; see {@code bridge/README.md} for the manual test plan.
 */
public final class ActionHandler {

    private static final MMLogger LOGGER = MMLogger.create(ActionHandler.class);

    private final Client client;

    public ActionHandler(Client client) {
        this.client = client;
    }

    public void handle(ActionMessage message) {
        if (message.type() == null) {
            LOGGER.warn("Action message without a type ignored: {}", message);
            return;
        }
        switch (message.type()) {
            case ActionMessage.MOVE -> handleMove(message);
            case ActionMessage.ATTACK -> handleAttack(message);
            case ActionMessage.END_PHASE -> handleEndPhase(message);
            case ActionMessage.CHAT -> handleChat(message);
            default -> LOGGER.warn("Unknown action type '{}' ignored", message.type());
        }
    }

    private void handleMove(ActionMessage message) {
        Game game = client.getGame();
        Entity entity = game.getEntityFromAllSources(message.entityId());
        if (entity == null) {
            LOGGER.warn("action.move for unknown entity {} ignored", message.entityId());
            return;
        }

        MovePath movePath = new MovePath(game, entity);
        for (String stepName : nullToEmpty(message.steps())) {
            try {
                movePath.addStep(MoveStepType.valueOf(stepName));
            } catch (IllegalArgumentException e) {
                LOGGER.warn("Unknown MoveStepType '{}' in action.move, skipped", stepName);
            }
        }
        client.moveEntity(entity.getId(), movePath);
    }

    private void handleAttack(ActionMessage message) {
        if (message.entityId() == null || message.targetId() == null) {
            LOGGER.warn("action.attack missing entityId/targetId, ignored: {}", message);
            return;
        }
        Vector<EntityAction> attacks = new Vector<>();
        for (Integer weaponId : nullToEmpty(message.weaponIds())) {
            attacks.add(new WeaponAttackAction(message.entityId(), message.targetId(), weaponId));
        }
        client.sendAttackData(message.entityId(), attacks);
    }

    private void handleEndPhase(ActionMessage message) {
        boolean done = message.done() == null || message.done();
        client.sendDone(done);
    }

    private void handleChat(ActionMessage message) {
        if (message.text() != null && !message.text().isBlank()) {
            client.sendChat(message.text());
        }
    }

    private static <T> List<T> nullToEmpty(List<T> list) {
        return list == null ? List.of() : list;
    }
}
