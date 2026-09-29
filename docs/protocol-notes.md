# MegaMek-Protokoll-Notizen (für die Bridge)

Grundlage: `vendor/megamek` @ `e601296070cf8b126389c24f3022c02876a9ac88` — dem
tatsächlich veröffentlichten Release-Commit von **v0.51.0** (06.06.2026), nicht
irgendein Dev-Snapshot. Das ist wichtig: MegaMeks `SERVER_VERSION_CHECK` verlangt
exakte Übereinstimmung des Versionsstrings zwischen Client und Server (siehe
Abschnitt "Login-/Verbindungsablauf" unten) — die Bridge muss also auf einer
Version stehen, die es tatsächlich als Release gibt, damit sie neben einer
Standard-MegaMek-Installation laufen kann (nicht auf `master`/HEAD, was einen
unveröffentlichten Entwicklungsstand mit eigenem, noch nicht existierendem
Versionsstring hätte). `megamek.client.HeadlessClient` und
`megamek.client.ui.clientGUI.CommanderGUI` sind KEIN Grund, einen Dev-Snapshot zu
brauchen — beide gibt es bereits seit Januar 2025, lange vor v0.51.0. Eine frühere
Version dieser Notiz behauptete fälschlich, `HeadlessClient` sei erst durch einen
unveröffentlichten "PR #6418" hinzugekommen; das war falsch und hat die Bridge
längere Zeit an eine Version gebunden, die kein reales Server-Install je hatte.
`HeadlessClient` ist eine offiziell unterstützte, GUI-lose `Client`-Unterklasse
(aktuell für MekHQ-Batches gedacht), die wir 1:1 wiederverwenden statt eine eigene
Client-Implementierung zu schreiben.

## Architekturüberblick auf MegaMek-Seite

```
IClient (Interface)
  └─ AbstractClient          – Verbindung (Socket), Packet-Dispatch-Loop, Login-Handshake
       └─ Client             – TW-spezifische Logik: Spielzustand (Game), sendXxx()-Methoden
            └─ HeadlessClient – GUI-lose Variante (kein Icon-Cache, MUL-Autosave bei Sieg)
```

- Transport: `AbstractConnection` (TCP-Socket, Java-Objektserialisierung/eigenes
  Framing), siehe `common/net/connections/`. Nicht direkt wiederverwendbar
  von Flutter aus — genau deshalb existiert die Bridge.
- Nachrichteneinheit: `megamek.common.net.packets.Packet` — ein `PacketCommand`
  (Enum, `common/net/enums/PacketCommand.java`, aktuell ~150 Werte) plus ein
  `Object[]` Payload. **Wichtig**: `PacketCommand.ordinal()` ist das
  Wire-Format — die Reihenfolge im Enum darf sich serverseitig nicht ändern,
  für die Bridge aber irrelevant, da wir nie roh serialisieren, sondern die
  von MegaMek bereits deserialisierten Java-Objekte weiterverarbeiten.
- Spielzustand: `megamek.common.game.Game` (Board(s), Entities, Players,
  Phase, Round, Forces, Reports). Der `Client` hält eine Instanz und aktualisiert
  sie beim Empfang von Packets; die Bridge liest ausschließlich aus `Game` und
  hört auf `GameListener`-Events (`common/event/GameListener.java`, praktisch
  per `GameListenerAdapter` überschreibbar), statt selbst Packets zu parsen.

## Login-/Verbindungsablauf (`AbstractClient.handleGameIndependentPacket`)

1. Bridge öffnet TCP-Verbindung (`AbstractClient.connect()`).
2. Server → Client: `SERVER_GREETING` ⇒ Client antwortet mit `CLIENT_NAME`.
3. Server → Client: `SERVER_VERSION_CHECK` ⇒ Client antwortet mit `CLIENT_VERSIONS`
   (muss exakt zur Server-`Version` passen, sonst `ILLEGAL_CLIENT_VERSION` und
   Disconnect — d. h. Bridge und Server-Docker-Image müssen dieselbe
   MegaMek-Version verwenden, siehe `docs/decisions.md`).
4. Server → Client: `LOCAL_PN` (lokale Player-Nummer), `SENDING_PLAYERS`,
   `SENDING_ENTITIES`, `SENDING_BOARD`, `SENDING_GAME_SETTINGS`,
   `SENDING_MAP_SETTINGS` etc. — der Client baut daraus sein `Game`-Objekt auf.
5. Lobby-Phase: Spieler setzt Team/Name via `sendPlayerInfo()`, Ready-Status via
   `sendDone(boolean)` (→ `PLAYER_READY`). `PHASE_CHANGE`-Packets steuern den
   Phasenwechsel (`GamePhase`-Enum: LOUNGE, DEPLOYMENT, MOVEMENT, FIRING,
   PHYSICAL, END, VICTORY, ...).

## Für das MVP relevante Packets/Client-Methoden → JSON-Mapping

| MegaMek-Seite | Richtung | Bridge-JSON-Ereignis/Aktion |
|---|---|---|
| `SERVER_GREETING`/`CLIENT_NAME`/`SERVER_VERSION_CHECK` | intern (Bridge↔Server) | `connection.status` (`connecting`→`connected`/`error`) an Mobile-Clients |
| `SENDING_PLAYERS`, `PLAYER_ADD`, `PLAYER_UPDATE`, `PLAYER_REMOVE`, `PLAYER_READY` | S→C | `state.players` (Snapshot) + `event.player_changed` |
| `SENDING_ENTITIES`, `ENTITY_ADD`, `ENTITY_UPDATE`, `ENTITY_MULTI_UPDATE`, `ENTITY_REMOVE`, `ENTITY_MOVE` | S→C | `state.entities` (Snapshot je Einheit: id, owner, Typ, Position, Facing, HP/Armor, Waffen) + `event.entity_changed` |
| `SENDING_BOARD` | S→C | `state.board` (Hex-Grid: Dimensionen + Terrain pro Hex, einmalig/bei Wechsel) |
| `PHASE_CHANGE` | S→C | `state.phase` (`LOUNGE`/`MOVEMENT`/`FIRING`/`PHYSICAL`/`END`/`VICTORY`/...) |
| `SENDING_TURNS`, `TURN` | S→C | `state.turn` (wer ist dran) |
| `ROUND_UPDATE` | S→C | `state.round` |
| `CHAT` | beide | `chat.message` |
| `PLAYER_READY` (`sendDone`) | C→S | Aktion `action.end_phase` / `action.set_ready` |
| `Client.moveEntity(id, MovePath)` (baut `ENTITY_MOVE`) | C→S | Aktion `action.move` (Schritt-Liste → `MovePath` mit `MoveStepType.FORWARDS`/`BACKWARDS`/`TURN_LEFT`/`TURN_RIGHT`/`LATERAL_LEFT`/`LATERAL_RIGHT`) |
| `Client.sendAttackData(aen, Vector<EntityAction>)` mit `WeaponAttackAction(entityId, targetId, weaponId)` | C→S | Aktion `action.attack` (Zieleinheit + Waffen-IDs) |
| `SENDING_REPORTS*` | S→C | `state.log` (Textreports, z. B. Trefferergebnisse) — im MVP nur durchgereicht, nicht strukturiert geparst |
| `GAME_VICTORY_EVENT` / `changePhase(VICTORY)` | S→C | `state.phase = VICTORY` + `event.game_over` |
| `MekSummaryCache.getMek(ref)` + `MekSummary.loadEntity()` + `Client.sendAddEntity(List<Entity>)` (baut `ENTITY_ADD`) | C→S | Aktion `action.add_unit` (fügt der eigenen Rosterliste einen Mek hinzu) |
| `new Princess(name, host, port)` + `.connect()` (eigener, zweiter In-Process-Client) | C→S | Aktion `action.add_bot` (siehe `BotManager`, verwaltet den Bot-Client separat vom Human-`Client`) |
| `Princess.sendAddEntity(List<Entity>)` (gleicher Call wie oben, auf dem Bot-Client) | C→S | Aktion `action.add_bot_unit` |
| `Client.sendMapSettings(MapSettings)` (baut `SENDING_MAP_SETTINGS`) | C→S | Aktion `action.select_board` |
| `SENDING_MAP_SETTINGS` (Server meldet verfügbare/gewählte Boards zurück) | S→C | `state.snapshot.availableBoards`/`.selectedBoards` (via `GameSettingsChangeEvent`) |
| `Client.sendDone(true)` auf dem Human-`Client` **und** jedem Bot-`Client` | C→S | Aktion `action.start_game` (kein eigenes Server-Packet — der Server wechselt selbst LOUNGE→DEPLOYMENT, sobald alle bereit sind und mindestens eine Entity existiert) |
| `MekSummaryCache.getAllMeks()` (lokal, kein Server-Roundtrip) | — | Aktion `action.unit_catalog_search` → Antwort `state.unit_catalog` (nur an den anfragenden Client, kein Broadcast) |

## Bewusst NICHT im MVP abgebildet (siehe CLAUDE.md "Bekannter Stand")

- Deployment-Detailoptionen (Minefields, Hidden Units, Artillery-Auto-Hit-Hexes)
- Force-/C3-Netzwerke, Schlepp-/Trailer-Mechanik (`ENTITY_BUILD_TRAIN`), Nova-CEWS
- Alle `CFR_*`-Packets (Client-Feedback-Requests wie AMS-Zuweisung, TAG-Ziel) —
  werden serverseitig ggf. mit Default-Antwort automatisch übersprungen; volle
  Unterstützung ist Folgearbeit.
- Speichern/Laden (`SEND_SAVEGAME`/`LOAD_SAVEGAME`/`LOAD_GAME`)
- Aerospace/Space-Combat-Packets (kein Nicht-Ziel-Bereich, siehe Auftrag)

## JSON-Übersetzung: Prinzip

Die Bridge serialisiert **niemals** rohe MegaMek-Objekte (z. B. `Entity`,
`Player`) direkt zu JSON — diese Klassen sind riesig, zyklisch verschachtelt
und Swing/Desktop-lastig. Stattdessen definiert die Bridge eigene, schlanke
DTOs (`bridge/src/main/java/.../dto/*.java`) und mappt die relevanten Felder
manuell. Das hält das JSON-Schema klein, stabil und unabhängig von
MegaMek-internen Refactorings. Details und das aktuelle Schema stehen in
`bridge/README.md` (Phase 1) bzw. werden dort versioniert (`schemaVersion`
Feld in jeder Nachricht).

## Vorhandene "minimal client"-Ansätze in MegaMek, die wir wiederverwenden

- `megamek.client.HeadlessClient` — Basis für `MegaMekBridgeClient`.
- `megamek.client.ui.clientGUI.CommanderGUI` — zeigt, wie MekHQ MegaMek fernsteuert
  (Programmatic-Control-Interface); als Referenz für Fernsteuerungs-API-Design
  genutzt, aber nicht direkt eingebunden (Swing-Abhängigkeiten).
- `megamek.client.bot.princess.*` — als Beispiel, wie ein Nicht-GUI-Client
  `Game`-Events konsumiert und `MovePath`/`WeaponAttackAction` baut (Referenz
  für unsere Action-Übersetzung, aber Princess selbst wird nicht eingebunden —
  kein KI-Bot im MVP).
