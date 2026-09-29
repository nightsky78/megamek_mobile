package megamekmobile.bridge.dto;

import java.util.List;

/**
 * Full game state snapshot, pushed to every connected mobile client whenever something relevant changes
 * (see {@code docs/decisions.md} #3 for the schema versioning rule and #8 for the envelope format).
 *
 * <p>The MVP always sends the whole snapshot rather than a diff - simpler to implement and reason about,
 * at the cost of some extra bandwidth on a large board. Diffing is a documented follow-up
 * (see CLAUDE.md "Bekannter Stand").</p>
 */
public record GameStateSnapshot(
      String type,
      int schemaVersion,
      String phase,
      int round,
      Integer localPlayerId,
      List<PlayerDto> players,
      List<EntityDto> entities,
      List<BoardDto> boards,
      List<String> availableBoards,
      List<String> selectedBoards) {

    public static final String TYPE = "state.snapshot";
    public static final int SCHEMA_VERSION = 1;

    public GameStateSnapshot(
          String phase,
          int round,
          Integer localPlayerId,
          List<PlayerDto> players,
          List<EntityDto> entities,
          List<BoardDto> boards,
          List<String> availableBoards,
          List<String> selectedBoards) {
        this(TYPE, SCHEMA_VERSION, phase, round, localPlayerId, players, entities, boards,
              availableBoards, selectedBoards);
    }
}
