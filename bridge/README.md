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
    {"id": 1, "name": "Pilot1", "team": 1, "done": false, "gameMaster": false, "bot": false},
    {"id": 2, "name": "Princess1", "team": 2, "done": true, "gameMaster": false, "bot": true}
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
    {"boardId": 0, "width": 16, "height": 17, "hexes": [
      {"x": 0, "y": 0, "level": 0, "theme": null, "terrain": []},
      {"x": 1, "y": 0, "level": 0, "theme": null, "terrain": [
        {"type": 1, "level": 2, "exits": 0},
        {"type": 13, "level": 1, "exits": 9}
      ]}
    ]}
  ],
  "availableBoards": ["AGoAC Base", "Sample Boards/CraterCityDay1"],
  "selectedBoards": ["AGoAC Base"]
}
```
`phase` is the name of a `megamek.common.enums.GamePhase` constant (`LOUNGE`,
`DEPLOYMENT`, `MOVEMENT`, `FIRING`, `PHYSICAL`, `END`, `VICTORY`, ...).

Each hex's `terrain` array lists the terrain features present (woods, water, roads,
buildings, ...), filtered to the types the mobile app actually renders (see
`GameStateMapper.RENDERED_TERRAIN_TYPES`). `terrain[].type` is a
`megamek.common.units.Terrains` int constant (e.g. `1` = `WOODS`, `13` = `ROAD`) -
the mobile client mirrors the relevant constants as literals in
`lib/features/game/terrain_types.dart` rather than round-tripping a lookup table,
the same convention already used for `MoveStepType`. `terrain[].level`'s meaning is
terrain-type-specific (woods canopy density, water depth, building class, ...).
`terrain[].exits` is a 6-bit hexside mask (`1 << direction`, direction `0`=N
clockwise to `5`=NW) used by roads/rivers/bridges - in the example above, a road
with `exits: 9` (`0b001001`) connects toward N and S.
`availableBoards`/`selectedBoards` are MegaMek's own board filenames (no `.board`
extension), sourced from `Game.getMapSettings()` - the server discovers and pushes
these automatically on connect and after every `action.select_board`.

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

**`action.add_unit`** - adds a mech to the local player's own roster (lobby phase only).
```json
{"type": "action.add_unit", "unitRef": "Atlas AS7-D"}
```
`unitRef` must be exactly the `ref` value from a `state.unit_catalog` entry (it's
`MekSummary.getName()`, not a hand-built "chassis model" string).

**`action.add_bot`** - connects a new Princess AI opponent under the given name (idempotent:
re-sending the same `botName` is a no-op if it's already connected).
```json
{"type": "action.add_bot", "botName": "Princess1"}
```

**`action.add_bot_unit`** - adds a mech to an already-added bot's roster.
```json
{"type": "action.add_bot_unit", "botName": "Princess1", "unitRef": "Timber Wolf Prime"}
```

**`action.select_board`** - picks the board for the match (single board only in the MVP).
```json
{"type": "action.select_board", "boardNames": ["AGoAC Base"]}
```

**`action.start_game`** - no fields. Calls `sendDone(true)` for the local player and every
connected bot; the server itself transitions LOUNGE -> DEPLOYMENT once every player (human and
bot) is done and at least one entity exists anywhere in the game - the bridge never forces the
phase directly.
```json
{"type": "action.start_game"}
```

**`action.unit_catalog_search`** - all fields optional; answered with a `state.unit_catalog`
reply sent only to the requesting client (not broadcast, since it isn't derived from `Game` state
at all).
```json
{"type": "action.unit_catalog_search", "text": "atlas", "clanOnly": false, "minTons": 50, "maxTons": 100, "limit": 50}
```

#### `state.unit_catalog`

Reply to one client's `action.unit_catalog_search` (see `megamekmobile.bridge.dto.UnitCatalogMessage`).
`totalMatches` is the match count *before* truncation to `limit` (default 50, capped at 200), so
the UI can show e.g. "50 of 8214 - refine your search".
```json
{
  "type": "state.unit_catalog",
  "schemaVersion": 1,
  "totalMatches": 3,
  "units": [
    {"ref": "Atlas AS7-D", "chassis": "Atlas", "model": "AS7-D", "unitType": "Mek",
     "tons": 100, "bv": 1897, "year": 3025, "techBase": "Inner Sphere", "clan": false}
  ]
}
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
