# Bridge

Java/Gradle module that connects to a MegaMek server as an ordinary (headless)
client and exposes a JSON/WebSocket API for the Flutter app. See the repo-root
`CLAUDE.md` for the overall architecture and `docs/protocol-notes.md` /
`docs/decisions.md` for the reasoning behind the choices below.

## Running

```bash
# from repo root, once: git submodule update --init --recursive
./gradlew :bridge:run --args="--host=localhost --port=2346 --player=Pilot1 --bridge-port=8080"
```

Configuration (CLI args override the matching env var):

| Env var | CLI flag | Default | Meaning |
|---|---|---|---|
| `MEGAMEK_HOST` | `--host=` | `localhost` | MegaMek dedicated server host |
| `MEGAMEK_PORT` | `--port=` | `2346` | MegaMek dedicated server port |
| `PLAYER_NAME` | `--player=` | `BridgePlayer` | Name this bridge logs in as (one MegaMek player slot per bridge process, see `docs/decisions.md` #4) |
| `BRIDGE_PORT` | `--bridge-port=` | `8080` | Port the mobile-facing WebSocket/REST API listens on |

## Building/testing standalone

```bash
./gradlew :bridge:build   # compile + test + jar
./gradlew :bridge:test
```

The `:bridge` project is a normal Gradle subproject; `:megamek` is pulled in
via a Gradle **composite build** against `vendor/megamek` (see root
`settings.gradle`), which in turn composite-builds `vendor/mm-data` (its own
`settings.gradle` requires that sibling directory — see `docs/decisions.md`
#1 and #5). Both are read-only git submodules; run
`git submodule update --init --recursive` once after cloning (~2 GB).

## API

### `GET /health`

Plain-text `ok` once the bridge process is up (does not guarantee the
MegaMek-server connection itself is up — check `connection.status` on the
WebSocket for that).

### `WS /ws`

One socket per mobile client. On connect, the bridge immediately sends a full
`state.snapshot`. From then on it pushes a fresh snapshot after every
structural game change (phase/turn/round, entities added/removed/changed,
players changed, board (re)generated) and a `chat.message` on every chat line.
The mobile client sends `action.*` messages back on the same socket.

Every message is a flat JSON object with `"type"` and `"schemaVersion"` fields
(see `docs/decisions.md` #3 and #8).

#### Server → Client messages

**`connection.status`**
```json
{"type": "connection.status", "schemaVersion": 1, "status": "connected", "detail": null}
```
`status` is one of `connected`, `error`.

**`state.snapshot`** (see `megamekmobile.bridge.dto.GameStateSnapshot`)
```json
{
  "type": "state.snapshot",
  "schemaVersion": 1,
  "phase": "MOVEMENT",
  "round": 3,
  "localPlayerId": 1,
  "players": [
    {"id": 1, "name": "Pilot1", "team": 1, "done": false, "gameMaster": false}
  ],
  "entities": [
    {
      "id": 42, "ownerId": 1, "chassis": "Atlas", "model": "AS7-D",
      "displayName": "Atlas AS7-D", "boardId": 0, "x": 7, "y": 12, "facing": 2,
      "armor": 180, "totalArmor": 212, "internal": 60, "totalInternal": 76,
      "destroyed": false, "pilotName": "Grimm", "gunnery": 3, "pilotHits": 0,
      "weapons": [{"equipmentId": 5, "name": "AC/20"}]
    }
  ],
  "boards": [
    {"boardId": 0, "width": 16, "height": 17, "hexes": [{"x": 0, "y": 0, "level": 0, "theme": null}]}
  ]
}
```
`phase` is the name of a `megamek.common.enums.GamePhase` constant (`LOUNGE`,
`DEPLOYMENT`, `MOVEMENT`, `FIRING`, `PHYSICAL`, `END`, `VICTORY`, ...).

**`chat.message`**
```json
{"type": "chat.message", "schemaVersion": 1, "text": "Pilot1: good hunting"}
```
`text` is the already-formatted line MegaMek's server sends (sender name is
baked in server-side, see `docs/protocol-notes.md`).

**`error`**
```json
{"type": "error", "schemaVersion": 1, "message": "Could not process message: ..."}
```
Sent back to the one client whose message failed to parse/apply; does not
disconnect the socket.

#### Client → Server messages (`megamekmobile.bridge.dto.ActionMessage`)

**`action.move`**
```json
{"type": "action.move", "entityId": 42, "steps": ["FORWARDS", "FORWARDS", "TURN_RIGHT"]}
```
`steps` are names of `megamek.common.enums.MoveStepType` constants. The
common ones for the MVP: `FORWARDS`, `BACKWARDS`, `TURN_LEFT`, `TURN_RIGHT`,
`LATERAL_LEFT`, `LATERAL_RIGHT`. An unknown step name is logged and skipped
rather than rejecting the whole move.

**`action.attack`**
```json
{"type": "action.attack", "entityId": 42, "targetId": 17, "weaponIds": [5, 9]}
```
`weaponIds` are `equipmentId` values from that entity's `weapons` list in the
last snapshot.

**`action.end_phase`**
```json
{"type": "action.end_phase", "done": true}
```
`done` defaults to `true` when omitted (equivalent to pressing MegaMek's
"Done" button). Sending `false` un-readies the player where the phase allows it.

**`action.chat`**
```json
{"type": "action.chat", "text": "moving to hold the ridge"}
```

## Adding a new packet type / DTO field

See CLAUDE.md "Konventionen" for the full checklist (DTO → mapper method →
test → `docs/protocol-notes.md` entry → schema version bump if breaking).

## Known limitations (see also CLAUDE.md "Bekannter Stand")

- Every broadcast re-sends the **entire** game state, including the full
  board hex list. Fine for the MVP's board sizes and round-paced updates;
  the documented follow-up is to only re-send `boards` when a
  `gameBoardNew`/`gameBoardChanged` event actually fires, and to diff
  `entities`/`players` instead of resending them whole.
- No reconnect/session resumption: if a mobile client's WebSocket drops, it
  simply reconnects and receives a fresh full snapshot; no action queue.
- `CFR_*` client-feedback-request packets (AMS assignment, TAG target
  selection, etc.) are not answered by the bridge.
