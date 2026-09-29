package megamekmobile.bridge.dto;

/** Outcome of a finished game; only present in the snapshot once the server has declared a result. */
public record GameResultDto(int winnerPlayerId, int winnerTeam, boolean localWon, String summary) {
}
