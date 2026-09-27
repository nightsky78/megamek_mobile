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
| `lib/features/lobby/` | Player list, ready toggle, chat (portrait) |
| `lib/features/game/` | Hex map (`hex_geometry.dart` + `hex_map_painter.dart`), phase bar, minimap, unit action panel (bottom sheet/bar), unit list and chat sheets (landscape-preferred) |
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
- Movement is step-button based, not tap-a-destination-hex pathfinding (see
  the doc comment on `UnitActionPanel`: computing a legal path is BattleTech
  rules logic, which this app leaves to the MegaMek server).
- No offline/reconnect handling: a dropped WebSocket requires reconnecting
  from the Connect screen.
