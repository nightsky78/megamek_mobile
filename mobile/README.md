# Mobile

Flutter app (iOS/Android) that talks exclusively to the bridge over
WebSocket/JSON - no MegaMek code or assets in this directory (see
`docs/licensing.md`). See the repo-root `CLAUDE.md` for the overall
architecture.

## Running

```bash
cd mobile
flutter pub get
flutter run   # pick a connected device/emulator
```

On the connect screen, enter the bridge's host/port (default `localhost:8080`
for the docker-compose setup in `docker/`).

## Build / test / lint

```bash
flutter analyze
flutter test
dart format .
```

## Structure

| Path | Contents |
|---|---|
| `lib/core/models/` | Dart mirrors of the bridge's JSON DTOs (see `bridge/README.md`), hand-written `fromJson` (no codegen) |
| `lib/core/net/bridge_client.dart` | The one WebSocket connection to the bridge |
| `lib/state/` | Riverpod `Notifier`s: `gameSessionProvider` (connection + snapshot + chat), `selectedUnitIdProvider` |
| `lib/features/connect/` | Host/port entry screen (portrait) |
| `lib/features/lobby/` | Lobby setup (portrait): player/team list, force panel (add/remove units, edit pilots, BV), mech catalog sheet with filters, bot setup (difficulty, own units, team), map browser (grouped by folder, filter), chat |
| `lib/features/game/` | Hex map (`hex_geometry.dart` + `hex_map_painter.dart`), phase bar with Continue, minimap, turn panels (`turn_panels.dart`: deploy, move with envelope/path preview/jump, fire with to-hit list, physical), unit detail sheet, combat log (`reports_sheet.dart`), victory overlay with New game |
| `lib/theme/` | Dark, touch-first `ThemeData` (Phase 3) |

`HomeShell` (`lib/app.dart`) picks Connect/Lobby/Game purely from
`gameSessionProvider`'s state - there is no named route stack, since the
bridge's own state already determines which screen makes sense (see
`docs/decisions.md` #6).

## Adding a new bridge message type

1. Add/extend a model in `lib/core/models/` mirroring the bridge DTO.
2. If it's a new server→client message, add a case to
   `BridgeMessage.fromJson` (`lib/core/models/bridge_message.dart`) and a
   matching class.
3. If it's a new client→server action, add a builder to `Actions`
   (`lib/core/models/actions.dart`).
4. Wire it into `GameSessionNotifier` (`lib/state/game_session.dart`).
5. Add a test next to the model (see `test/*_test.dart` for the pattern:
   build a JSON literal matching `bridge/README.md`'s example, assert the
   parsed fields).

## Known limitations (see also CLAUDE.md "Bekannter Stand")

- Single board only: `GameStateSnapshot.boards` can carry more than one
  (e.g. multi-level maps), but the UI currently always renders
  `boards.first`.
- Movement is tap-a-destination: the bridge computes the reachable hexes and
  the path with MegaMek's own path finder; the app contains no rules logic.
- A dropped WebSocket shows a reconnect banner and reconnects with backoff. If
  the bridge itself restarts mid-game, the player slot is lost and the app
  lands in the lobby.
- Charge/DFA, torso twist, hidden units and minefields are not exposed.
