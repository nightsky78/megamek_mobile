package megamekmobile.bridge;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class BotManagerTest {

    @Test
    void difficultyPresetsMapToPrincessBehaviours() {
        assertEquals("COWARDLY", BotManager.behaviorNameFor("easy"));
        assertEquals("DEFAULT", BotManager.behaviorNameFor("normal"));
        assertEquals("DEFAULT", BotManager.behaviorNameFor(null));
        assertEquals("RUTHLESS", BotManager.behaviorNameFor("HARD"));
        assertEquals("BERSERK", BotManager.behaviorNameFor("berserk"));
    }
}
