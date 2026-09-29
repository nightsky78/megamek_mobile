# MegaMek Mobile

## Projekt & Architektur

Ziel: MegaMek (Java, Client/Server-BattleTech-Simulator) über eine schlanke
JSON/WebSocket-Bridge mobil (Flutter, iOS+Android) spielbar machen, ohne
MegaMeks Spiellogik neu zu implementieren oder den MegaMek-Server zu verändern.

```
[Flutter App] <--WebSocket/JSON--> [Bridge (Java/Javalin)] <--MegaMek-Protokoll (Sockets)--> [MegaMek-Server, unverändert]
```

Die Bridge verhält sich gegenüber dem MegaMek-Server wie ein ganz normaler
Client (sie erweitert `megamek.client.HeadlessClient`), hält den von MegaMek
gelieferten Spielzustand (`Game`-Objekt) im Speicher, übersetzt ihn in eigene
schlanke JSON-DTOs und pusht sie per WebSocket an beliebig viele verbundene
Mobile-Clients. Aktionen (Bewegen, Angreifen, Chat, Phase beenden) laufen in
die andere Richtung: JSON-Action → Bridge ruft passende `Client`-Methode auf
(z. B. `moveEntity`, `sendAttackData`, `sendDone`) → MegaMek-Server verarbeitet
sie wie bei jedem anderen Client.

Ein Bridge-Prozess = eine MegaMek-Client-Verbindung = ein Spieler-Slot.
Mehrere Mobile-Geräte können sich mit derselben Bridge verbinden (teilen sich
den Spieler-Slot); zwei Spieler = zwei Bridge-Instanzen (siehe
`docs/decisions.md` #4).

## Repo-Struktur

| Verzeichnis | Inhalt |
|---|---|
| `bridge/` | Java/Gradle-Modul: MegaMek-Client-Wrapper + Javalin-WebSocket/REST-API. Bindet `vendor/megamek` als Compile-Dependency ein. |
| `mobile/` | Flutter-App (iOS/Android), spricht ausschließlich mit der Bridge, kein MegaMek-Code/-Assets. |
| `docs/` | `protocol-notes.md` (MegaMek-Packet↔JSON-Mapping), `licensing.md`, `decisions.md` (ADRs), `roadmap.md` (Weg zum spielbaren MVP + spätere plattformübergreifende Mehrspieler-Erweiterung; aktueller als "Bekannter Stand" unten). |
| `vendor/megamek`, `vendor/mm-data` | Git-Submodule, read-only Referenzen auf die offiziellen MegaMek-Repos (siehe `docs/decisions.md` #1, #5). Nach Klonen: `git submodule update --init --recursive` (lädt ca. 2 GB, nur für lokale Bridge-Builds/CI nötig, nicht fürs bloße App-Entwickeln). |
| `docker/` | `docker-compose.yml`, Dockerfiles für MegaMek-Server + Bridge. |

## Lokal starten

### MegaMek-Server + Bridge (Docker)

```bash
git submodule update --init --recursive   # einmalig, ~2 GB
docker compose -f docker/docker-compose.yml up --build
```

Hinweis: `vendor/mm-data` enthält einen nicht-ASCII-Dateinamen; ohne
UTF-8-Locale bricht das Daten-Staging beim Bauen ab (siehe
`docs/decisions.md` #11). Die Dockerfiles setzen `LANG=C.UTF-8` bereits
selbst; wer die Gradle-Befehle unten *außerhalb* von Docker ausführt, sollte
`LANG=C.UTF-8 LC_ALL=C.UTF-8` lokal exportieren, falls die System-Locale kein
UTF-8 ist (`locale` zum Prüfen).

Startet: `megamek-server` (dedizierter Server, Port 2346) + `bridge`
(WebSocket/REST auf Port 8080, verbindet sich intern mit `megamek-server:2346`).
Für einen zweiten Spieler: zweite Bridge-Instanz mit anderem
`BRIDGE_PORT`/`PLAYER_NAME` (siehe `docker/docker-compose.yml`, Service
`bridge-player2`, auskommentiert als Vorlage).

### Bridge allein (ohne Docker, gegen laufenden Server)

```bash
./gradlew :bridge:run --args="--host=localhost --port=2346 --player=Pilot1 --bridge-port=8080"
```
(Details/aktuelle Argumente: `bridge/README.md`.)

### Flutter-App

```bash
cd mobile
flutter pub get
flutter run   # Emulator/Gerät; Host/Port der Bridge werden im Connect-Screen eingegeben
```

## Build/Test/Lint

| | Befehl |
|---|---|
| Bridge bauen | `./gradlew :bridge:build` (Repo-Root) |
| Bridge testen | `./gradlew :bridge:test` (Repo-Root) |
| Flutter analysieren | `cd mobile && flutter analyze` |
| Flutter testen | `cd mobile && flutter test` |
| Flutter formatieren | `cd mobile && dart format .` |

(`./gradlew` liegt im Repo-Root und ist auf Gradle 9.4.1 gepinnt — siehe
`docs/decisions.md` #9 — nicht `vendor/megamek/gradlew` direkt verwenden.
Die Bridge hängt per Composite Build an `vendor/megamek`, siehe
`bridge/build.gradle` und `settings.gradle` im Repo-Root.)

## Wichtige Architekturentscheidungen (Kurzfassung, Details: `docs/decisions.md`)

1. MegaMek/mm-data als Submodule, gepinnt auf `master`-Commit
   (`f02023f9a...`/`e80f64ada...`), nicht auf Release-Tag — wegen
   `HeadlessClient` (nur auf master vorhanden zum Recherchezeitpunkt).
2. Bridge-Framework: **Javalin** (reines Java, WebSocket eingebaut).
3. JSON-DTOs statt roher MegaMek-Objekt-Serialisierung; `schemaVersion`-Feld.
4. Ein Bridge-Prozess pro Spieler-Slot; mehrere Mobile-Clients pro Bridge möglich.
5. MegaMek-Server-Docker-Image: aus Quellcode gebaut (Versionskopplung an
   Submodule-Commit; siehe Begründung in `docs/decisions.md` #5).
6. Flutter State-Management: **Riverpod**.
7. Hex-Map: eigener `CustomPainter`, kein Fertig-Paket.
8. Bridge↔Mobile: ein WebSocket-Kanal, flache JSON-Nachrichten `{type, schemaVersion, ...felder}` (kein `payload`-Wrapper).

## Bekannter Stand

Wird nach jeder Phase aktualisiert.

- **Phase 0 (Recherche)**: abgeschlossen. Submodule eingebunden,
  `docs/protocol-notes.md`, `docs/licensing.md`, `docs/decisions.md` geschrieben.
- **Phase 1 (Bridge)**: abgeschlossen. `bridge/` kompiliert und die Unit-Tests
  laufen gegen den echten `vendor/megamek`-Sourcecode (Composite Build,
  `./gradlew :bridge:test` grün). WebSocket-API (`/ws`, `/health`),
  Game-Listener → Snapshot-Broadcast, Action-Handling für Move/Attack/EndPhase/
  Chat implementiert (Details: `bridge/README.md`). Docker-Setup unter
  `docker/` (Server + Bridge, jeweils Multi-Stage-Build aus Quellcode).
- **Phase 2 (Mobile MVP)**: abgeschlossen. Flutter-App (`mobile/`) mit
  Connect-Screen, Lobby (Spielerliste, Ready-Toggle, Chat), Hex-Map
  (`CustomPainter`, Pan/Zoom via `InteractiveViewer`), Einheiten-Auswahl +
  Detailanzeige, Move-Step-Builder, Attack-Builder (Ziel+Waffen), Phasenleiste
  mit Done-Button. Riverpod-State (`gameSessionProvider`,
  `selectedUnitIdProvider`). `flutter analyze` sauber, 18 Unit-/Widget-Tests
  grün (`flutter test`). iOS-/Android-Plattformordner vorhanden
  (`flutter create . --platforms ios,android`); im Sandbox-Container ohne
  Gerät/Emulator stattdessen per Web-Build + headless Chromium visuell
  verifiziert (Screenshot des Connect-Screens im Chat).
- **Phase 3 (UI/UX)**: abgeschlossen (siehe `mobile/README.md`): Bottom-Sheets,
  kontextsensitive Bottom-Panels, Minimap, Landscape für die Karte, dunkles
  Touch-Theme (`lib/theme/app_theme.dart`).
- **Phase 4-6 (MVP-Umfang, siehe `docs/roadmap.md`)**: abgeschlossen.
  Bridge: `BridgeSession`/`BotManager`, Deployment-/Move-/Attack-/Physical-Aktionen
  mit Optionen-Antworten, `state.report`, Snapshot mit Zug-Info/Ergebnis/Heat/
  Trefferzonen, automatische `CFR_*`-Antworten, Force-Verwaltung, `action.new_game`
  (`/reset <server-password>`, daher `--server-password`). Mobile: kompletter
  Lobby-Aufbau (Katalogfilter, Roster, Piloten, Bots mit Schwierigkeit, Karten-
  browser), Deployment, Movement, Fire, Physical, Combat-Log, Sieg/Niederlage,
  Reconnect. `flutter analyze` sauber, `flutter test` 42 Tests grün.

### Stand ggü. dem Abnahmekriterium

Auf dem Android-Emulator gegen lokalen MegaMek-v0.51.0-Server + Bridge
durchgespielt (Lobby -> Deployment -> mehrere Runden Move/Fire/Physical ->
Niederlage-Overlay -> Neues Spiel; Reconnect nach Bridge-Neustart).

**Nicht** verifiziert: echtes Android-/iOS-Gerät (Touch, Pan/Zoom), zwei
Mobile-Spieler gleichzeitig, `docker compose up`.

### Bekannte Einschränkungen

- Kein Aerospace-/Weltraumkampf, nur Bodengefechte.
- Kein Speichern/Laden von Spielständen über die App.
- Nicht übersetzt: Minefields, Hidden Units, Artillery-Auto-Hit, Force-/C3-
  Netzwerke, Trailer/Train, Charge/DFA, Torso-Twist.
- `CFR_*`-Anfragen werden von der Bridge mit Standardwerten beantwortet (keine
  Nutzerauswahl).
- Nach `VICTORY` sterben die Bots; sie müssen in der neuen Lobby erneut
  hinzugefügt werden.
- Während die Bridge über `./gradlew :bridge:run` läuft, keine anderen
  Gradle-Builds starten (überschreiben `MegaMek.jar`, dann `NoClassDefFoundError`).
- Phase 7 (zentraler Server, PC-Client-Bridge) ist nur ein grober Entwurf.

## Konventionen

- **Commits**: kurzer Imperativ-Titel, `bridge:`/`mobile:`/`docs:`-Präfix wo
  sinnvoll (z. B. `bridge: add entity DTO mapping for ENTITY_UPDATE`).
- **Neue Packet-Typen in der Bridge ergänzen**: (1) DTO in
  `bridge/src/main/java/megamekmobile/bridge/dto/` hinzufügen, (2)
  Mapping-Methode in `mapping/GameStateMapper.java` (Zustand) oder
  `mapping/ActionHandler.java` (Aktionen) ergänzen, (3) Unit-Test in
  `bridge/src/test/java/megamekmobile/bridge/mapping/GameStateMapperTest.java`
  ergänzen, (4) Zeile in der Tabelle in `docs/protocol-notes.md` und im
  entsprechenden Abschnitt von `bridge/README.md` ergänzen, (5) bei
  Breaking Change: `schemaVersion` in `docs/decisions.md` #3 erhöhen. Auf der
  Mobile-Seite dann analog: Dart-Modell in `mobile/lib/core/models/`
  ergänzen/anpassen (siehe `mobile/README.md` "Adding a new bridge message
  type").
- **JSON-Schema-Versionierung**: `schemaVersion`-Feld in jeder WS-Nachricht,
  siehe `docs/decisions.md` #3.
- **Code-Style Bridge**: Standard-Java-Konventionen (4 Spaces, keine Tabs);
  kein eigenes Checkstyle-Profil im MVP.
- **Code-Style Mobile**: Standard `dart format` + `flutter_lints`.

## Rechtliches

MegaMek-Code: GPL-3.0-or-later. MegaMek-Daten/Assets: CC-BY-NC-4.0. Details
und Konsequenzen für dieses Repo: `docs/licensing.md`. Dieses Projekt ist ein
inoffizielles Fan-Tool, nicht mit Catalyst Game Labs/Microsoft/MegaMek-Team
affiliiert.
