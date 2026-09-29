# Roadmap: playable MVP → cross-platform multiplayer

Status as of 2026-09-29 (Phases 4-6 MVP implemented, see section 1). Continues the phase numbering in `CLAUDE.md` ("Bekannter
Stand", Phases 0–3). Where this file and `CLAUDE.md` disagree, this file reflects what
was actually verified end-to-end; `CLAUDE.md` is corrected in Phase 4.

---

## 1. Where we are

Phases 4, 5 and the MVP items of Phase 6 (6.1, 6.2, 6.4, 6.8) are implemented. Verified
on an Android emulator <-> bridge <-> unmodified MegaMek v0.51.0 dedicated server (2026-09-29):
lobby setup (catalog filters, add/remove units, pilot edit, bot with difficulty and units,
map browser), start, initiative report, deployment, movement (envelope, path preview),
firing with to-hit list, combat log with real damage resolution, physical attack, several
rounds against Princess, victory/defeat overlay, New game back to the lobby, and reconnect
after a bridge restart.

| Area | State |
|---|---|
| Connect, lobby, chat, reconnect | Works |
| Mech catalog with filters, force management, pilots, BV | Works |
| Bot (difficulty, units, team), map browser | Works |
| Deployment, turn awareness, movement, firing, physical | Works (emulator) |
| Combat log, unit detail (heat, ammo, per-location damage) | Works |
| `CFR_*` requests | Auto-answered with defaults |
| Victory / defeat, New game (`/reset`) | Works |
| Not verified | Real phone/touch (pan/zoom, ergonomics), iPhone, two mobile players, `docker compose up` |
| Known polish items | Phase title truncates next to the Continue button; portrait bottom panel covers part of the map; zoom resets between phases |
| Not in MVP | 6.3 random lance, 6.5 map preview, 6.6 generated map, 6.7 multi-board maps; charge/DFA, torso twist |

---

## 2. Definition of "fully playable MVP"

With only the phone app — no desktop tools, no scripts — a player can set up and finish
a game against the bot, picking from many mechs and maps, and the app survives normal
phone behavior.

**Acceptance scenarios**

1. **Solo vs bot.** Connect → pick 1–4 mechs using filters → add a bot at a chosen
   difficulty with its own mechs → pick a map (or random) → start → deploy → play
   movement, firing and physical phases every round, with the combat log visible →
   reach a victory/defeat screen → start a new game.
2. **Cross-platform smoke test.** One player on the phone (through the bridge) and one
   on desktop MegaMek, both connected to the same standard v0.51.0 server — for example
   an existing LAN server. Today's architecture already allows this,
   because the bridge is just another MegaMek client. This is the direct LAN path; the
   central-server path, where PCs connect through the client bridge on 443, is Phase 7.
3. **Resilience.** Background the app or drop the network mid-turn → the app reconnects
   and continues from the current state.
4. **Real devices.** At least one Android phone and one iPhone. iOS builds need
   macOS/Xcode, which the current dev machine doesn't have.

---

## 3. Phase 4 — Stabilize (do first)

| # | Item | Why |
|---|---|---|
| 4.1 | Commit the pending work in logical commits (version pin, lobby setup, terrain rendering, fixes) | ~46 files uncommitted |
| 4.2 | Detect socket close in the app (`onDone` in `GameSessionNotifier`), show "disconnected", reconnect with backoff, re-request snapshot | Today a dead socket looks alive and taps silently do nothing |
| 4.3 | Replace `SafeArea` in `unit_action_panel.dart` with manual bottom padding | Same hit-test bug fixed in the lobby; this panel holds the move/fire buttons |
| 4.4 | Verify pan/zoom on a real device; fix if it's real | Can't play on boards bigger than the screen without it |
| 4.5 | Fix stale `CLAUDE.md`: decision #1 (still claims a `master` pin and "HeadlessClient only on master"), "Bekannter Stand", "Nicht verifiziert" | Wrong docs led to the original version-mismatch bug |
| 4.6 | Introduce a `BridgeSession` class wrapping `MegaMekBridgeClient` + `BotManager` (only one instance for now) | Cheap now; the seam multi-session support needs later (§6) |

Size: **S–M**.

---

## 4. Phase 5 — Complete the turn loop (core playability)

Each item needs a bridge change and a mobile change. The MegaMek APIs listed are
confirmed to exist in the pinned source.

| # | Item | Bridge | Mobile |
|---|---|---|---|
| 5.1 | **Turn awareness** | Add active player and actable entity ids to the snapshot (`Game.getTurnForPlayer`, `GameTurn`) | "Your turn" banner; highlight units that may act; disable actions otherwise |
| 5.2 | **Deployment** | Legal hexes for the selected unit via `Board.isLegalDeployment(Coords, Entity)`; new `action.deploy {entityId, x, y, facing}` → `Client.deploy(...)` | Highlight legal hexes (the painter's `highlightedHexes` exists but is unused), tap to place, facing picker |
| 5.3 | **Movement** | Add walk/run/jump MP (`getWalkMP/RunMP/JumpMP`) and MP used; allow `START_JUMP` and turn-only paths; return server rejections as `error` | Show MP budget, path preview via `highlightedHexes`, jump toggle. **First, verify a plain move works end-to-end.** |
| 5.4 | **Firing** | To-hit number per weapon/target, range, line of sight | Show to-hit next to each weapon; optional torso twist |
| 5.5 | **Physical attacks** | Punch/kick first (charge/DFA later), or an explicit "skip" | Physical attack builder in the action panel |
| 5.6 | **Combat log** | Listen for `GameReportEvent`; send `state.report` as plain text (MegaMek reports are HTML-ish) | Log sheet, plus a per-phase result summary |
| 5.7 | **Unit status** | Extend `EntityDto`: heat (`getHeat`), ammo per bin, armor/internal per location, crits, pilot hits, prone/shutdown/immobile | Unit detail sheet; heat and damage indicators on the map marker |
| 5.8 | **CFR handling** | Auto-answer `CFR_*` with safe defaults (AMS target, TAG, etc.) so rounds never stall | Optional later: let the user choose |
| 5.9 | **End of game** | Surface victory result and per-unit summary | Victory/defeat screen → back to lobby / new game |

Size: **L** — the bulk of the MVP. Order: 5.1 → 5.2 → 5.3 → 5.6 → 5.4 → 5.7 → 5.8 → 5.5 → 5.9.
Without 5.1, 5.2 and 5.6 nobody can play; the rest adds depth.

---

## 5. Phase 6 — Mech and map choice

| # | Item | Notes |
|---|---|---|
| 6.1 | Catalog filters in the UI: unit type, weight class, tech base, era/year, BV range | The bridge already filters by type, clan and tonnage (`UnitCatalogMapper`) — extend with year/BV |
| 6.2 | Force management: remove unit (`sendDeleteEntities`), edit pilot gunnery/piloting, BV total per side | |
| 6.3 | Balanced forces: BV budget, "random lance" from MegaMek's random unit tables (loaded by `RandomUnitGenerator`) | Saves hunting through ~11,000 units |
| 6.4 | Map browser: group by folder (`GrassLands/`, `Deserts/`, …), filter by size, search | Current list is flat and huge |
| 6.5 | Map preview thumbnail rendered with `HexMapPainter` | Needs a preview action that loads a board file on the bridge host — requires the bridge to know the MegaMek data dir (true when installed next to a standard install) |
| 6.6 | Random/generated map | `MapSettings.BOARD_GENERATED` (the server's default "[GENERATED]") |
| 6.7 | Multi-board mosaic maps | Mobile currently renders only `boards.first` |
| 6.8 | Bot setup: difficulty presets from `BehaviorSettingsFactory`, multiple bots, team assignment | |

Size: **M**. 6.1, 6.2, 6.4 and 6.8 are MVP; 6.3, 6.5, 6.6 and 6.7 can slip to after the MVP.

**MVP = Phases 4 + 5 + the MVP items of Phase 6.**

---

## 6. Phase 7+ — Central server, cross-platform multiplayer (ROUGH DRAFT)

> Rough draft, not planned in detail. Revisit after the MVP (Phases 4–6); only the
> points in §7 constrain current work.

**Idea.** A central server hosts games; mobile and PC players join from anywhere.
Only port 443 is public; MegaMek servers stay on an internal network. MegaMek itself and
its protocol stay unmodified.

**Two dedicated, separately installed bridges:**

- **Server bridge** (today's `bridge/`), on the central server. `/ws`: the JSON gateway
  mobile apps already use (the server bridge *is* the MegaMek client, one session per
  mobile player). New `/tunnel`: relays bytes for PC client bridges. Also accounts, game
  membership, game hosting (one MegaMek server container per game).
- **Client bridge** (new), on each player's PC next to desktop MegaMek. Signs the player
  in, opens a TLS tunnel to the server bridge on 443, and offers it to the local MegaMek
  client as `localhost:<port>` — it can launch MegaMek in `-client` mode with server, port
  and player name pre-filled. Carries MegaMek's bytes opaquely, so no MegaMek patch.

```
 PC:    MegaMek client --TCP localhost--> Client bridge ==wss:443==> Server bridge /tunnel --> MegaMek server (game)
 Phone: Mobile app ==================================wss:443==> Server bridge /ws (JSON) --> MegaMek server (game)
```

**Authentication and authorization.** MegaMek has no join authentication, so the bridges
provide it. The client bridge has its own sign-in flow (browser-based OAuth for desktop
apps, token in the OS credential store), then gets a short-lived, game-bound ticket to
open the tunnel. Mobile signs in inside the app. Per-game roles (host, player, spectator).

**Work areas (unordered):** multi-session server bridge and mobile reconnect; accounts
and authorization; game hosting; client bridge app and installers (Windows/macOS/Linux);
tunnel protocol with keepalive; local-vs-game MegaMek version check before connecting;
enforcing the authorized player name on the tunnel; strict MegaMek version policy (update
`vendor/megamek` and `vendor/mm-data` together); push notifications for "your turn"; TLS
and rate limiting; snapshot diffs; licensing and code signing.

**Known concerns:** a dropped tunnel disconnects the desktop client (it rejoins by name);
some networks block WebSocket upgrades; installer code signing costs money.

**Open decisions:** one public instance vs. self-hostable; built-in accounts vs. external
OpenID Connect; one account system for mobile and PC or separate; client bridge in Java
vs. a native binary; where bots run; whether browser players are in scope.

---

## 7. Decisions to make now so the MVP doesn't block multiplayer

- **Session seam now** (4.6): all new bridge code goes through `BridgeSession`, never a
  global client. This also keeps MegaMek-client code out of the future `/tunnel` relay,
  which must stay a plain byte pipe.
- **`bridge/` is the server bridge.** Name new server-side code accordingly; the client
  bridge becomes a sibling module later, not part of `bridge/`.
- **One MegaMek client per human** — never share a client between two humans, and never
  aggregate snapshots across sessions (breaks hidden-information games).
- **Stay on official MegaMek releases** (currently v0.51.0) — cross-platform play with
  desktop users depends on it.
- **Additive protocol changes only** during the MVP; add a capability/version handshake
  (`schemaVersion` exists) before multiplayer, so old apps fail clearly.

---

## 8. Sequencing overview

| Phase | Goal | Size | Depends on |
|---|---|---|---|
| 4 | Stabilize, commit, session seam | S–M | — |
| 5 | Complete turn loop | L | 4 |
| 6 (MVP part) | Mech/map/bot choice | M | 4 (parallel with 5 possible) |
| **MVP** | Acceptance scenarios 1–4 | | 4, 5, 6 |
| 7 (draft) | Central server, client bridge, multiplayer — plan after MVP | XL | MVP |

---

## 9. Risks and unknowns

- **Pan/zoom** may be an adb-input artifact or a real bug — resolve on a real device (4.4).
- **`CFR_*` auto-answers** use defaults; unusual units (AMS, TAG, artillery) are untested.
- **iOS** hasn't been built at all; needs macOS/Xcode and signing.
- **Board previews** need MegaMek data files on the bridge host — fine next to a standard
  install, needs a design for a central hosted service.
- **Performance** of full snapshots on large maps with many clients is unmeasured.
