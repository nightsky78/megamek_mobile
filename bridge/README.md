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
  "selectedBoards": ["AGoAC Base"],
  "turnPlayerId": 1,
  "myTurn": true,
  "actableEntityIds": [42],
  "result": null
}
```
`turnPlayerId`/`myTurn`/`actableEntityIds` say whose move it is and which of the local
player's units may act. `result` is only set in `VICTORY`:
`{"winnerPlayerId": -1, "winnerTeam": 2, "localWon": false, "summary": "Winner: team 2"}`.
`EntityDto` additionally carries `tons`, `bv`, `unitType`, `piloting`, `heat`, `heatCapacity`,
`walkMp`/`runMp`/`jumpMp`, `prone`/`shutDown`/`immobile`/`deployed`, `locations[]`
(armor/internal per location), `ammo[]` and `damagedEquipment[]`. Undeployed units have
`x = y = -1`.
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

**`action.add_bot`** also accepts `difficulty`: `easy`, `normal`, `hard` or `berserk`.

**Turn loop actions** (replies go only to the requesting client, unless noted):

| Action | Fields | Reply / effect |
|---|---|---|
| `action.deploy_options` | `entityId` | `state.deploy_options` `{entityId, hexes:[{x,y}]}` |
| `action.deploy` | `entityId, x, y, facing` | `Client.deploy`; snapshot broadcast |
| `action.move_options` | `entityId, mode` (`WALK`/`RUN`/`JUMP`/`BACKWARDS`) | `state.move_options` `{walkMp, runMp, jumpMp, hexes:[{x,y,mp}]}` |
| `action.move_preview` | `entityId, mode, x, y, facing?` | `state.move_preview` `{legal, mpUsed, facing, path, message}` |
| `action.move_to` | as preview; no `x`/`y` = stand still / turn only | sends the move |
| `action.attack_options` / `action.physical_options` | `entityId, targetId` | `state.attack_options` `{range, options:[{key, name, toHit, probability, description, damage, heat, possible}]}` |
| `action.attack` | `entityId, targetId, weaponIds` (empty = skip) | `sendAttackData` |
| `action.physical` | `entityId, targetId?, kind?` (`PUNCH_LEFT`/`PUNCH_RIGHT`/`KICK`); no target = skip | physical attack |
| `action.remove_unit` | `entityId` | removes from whichever client owns it |
| `action.set_pilot` | `entityId, gunnery?, piloting?` | edits the crew |
| `action.set_team` | `team, botName?` | team of the local player or a bot |
| `action.new_game` | - | after `VICTORY`: sends `/reset <server password>`; the server returns to the lobby (bots disconnect and must be re-added) |
| `action.ping` | - | keep-alive; no reply needed |

Report phases (`*_REPORT`) wait for `action.end_phase` (Continue). The bridge answers
`CFR_*` client-feedback requests itself (see Known limitations). The server password
(`--server-password=` / `SERVER_PASSWORD`) is only needed for `action.new_game`.

**`state.report`** (broadcast): `{"type": "state.report", "round": 1, "phase": "FIRING_REPORT", "text": "Weapons fire for ..."}` - the server's
game report as plain text, one message per report chunk.

`action.unit_catalog_search` additionally takes `minYear`, `maxYear`, `minBv`, `maxBv`,
`techBase` (`Inner Sphere`/`Clan`) and `unitType` (`Mek`, `Tank`, `BattleArmor`, `Infantry`,
`ProtoMek`, `VTOL`, `Naval`).

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
- No session resumption on the bridge: if a mobile client's WebSocket drops, it
  reconnects (the app does this with backoff) and receives a fresh full snapshot;
  there is no action queue.
- `CFR_*` client-feedback requests are auto-answered with safe defaults (no user choice yet).
- One bridge process = one player slot; if the bridge restarts mid-game the player slot is
  lost and the app lands in the lobby again.
- Don't rebuild `vendor/megamek`'s `MegaMek.jar` (e.g. another Gradle build) while the bridge
  runs via `./gradlew :bridge:run`; the bot threads then fail with `NoClassDefFoundError`.
  Restart the bridge afterwards.
