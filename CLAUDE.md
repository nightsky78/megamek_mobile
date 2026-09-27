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
| `docs/` | `protocol-notes.md` (MegaMek-Packet↔JSON-Mapping), `licensing.md`, `decisions.md` (ADRs). |
| `vendor/megamek`, `vendor/mm-data` | Git-Submodule, read-only Referenzen auf die offiziellen MegaMek-Repos (siehe `docs/decisions.md` #1, #5). Nach Klonen: `git submodule update --init --recursive` (lädt ca. 2 GB, nur für lokale Bridge-Builds/CI nötig, nicht fürs bloße App-Entwickeln). |
| `docker/` | `docker-compose.yml`, Dockerfiles für MegaMek-Server + Bridge. |

## Lokal starten

### MegaMek-Server + Bridge (Docker)

```bash
git submodule update --init --recursive   # einmalig, ~2 GB
docker compose -f docker/docker-compose.yml up --build
```

Startet: `megamek-server` (dedizierter Server, Port 2346) + `bridge`
(WebSocket/REST auf Port 8080, verbindet sich intern mit `megamek-server:2346`).
Für einen zweiten Spieler: zweite Bridge-Instanz mit anderem
`BRIDGE_PORT`/`PLAYER_NAME` (siehe `docker/docker-compose.yml`, Service
`bridge-player2`, auskommentiert als Vorlage).

### Bridge allein (ohne Docker, gegen laufenden Server)

```bash
cd bridge
../vendor/megamek/gradlew -p . run --args="--host=localhost --port=2346 --player=Pilot1 --bridge-port=8080"
```
(Details/aktuelle Argumente: `bridge/README.md`, Phase 1.)

### Flutter-App

```bash
cd mobile
flutter pub get
flutter run   # Emulator/Gerät; Host/Port der Bridge werden im Connect-Screen eingegeben
```

## Build/Test/Lint

| | Befehl |
|---|---|
| Bridge bauen | `cd bridge && ../vendor/megamek/gradlew build` |
| Bridge testen | `cd bridge && ../vendor/megamek/gradlew test` |
| Flutter analysieren | `cd mobile && flutter analyze` |
| Flutter testen | `cd mobile && flutter test` |
| Flutter formatieren | `cd mobile && dart format .` |

(Bridge nutzt den Gradle-Wrapper aus `vendor/megamek`, da die Bridge per
Composite Build an dessen Root hängt — Details in `bridge/build.gradle` und
`settings.gradle` im Repo-Root.)

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
8. Bridge↔Mobile: ein WebSocket-Kanal, JSON-Envelope `{type, schemaVersion, payload}`.

## Bekannter Stand

Wird nach jeder Phase aktualisiert.

- **Phase 0 (Recherche)**: abgeschlossen. Submodule eingebunden,
  `docs/protocol-notes.md`, `docs/licensing.md`, `docs/decisions.md` geschrieben.
- **Phase 1 (Bridge)**: siehe unten, wird nach Implementierung ergänzt.
- **Phase 2 (Mobile MVP)**: ausstehend.
- **Phase 3 (UI/UX)**: ausstehend.

### Bekannte Einschränkungen (gilt für den gesamten MVP)

- Kein Aerospace-/Weltraumkampf, nur Bodengefechte (Meks/Vehicles/Infantry).
- Kein KI-Bot (Princess).
- Kein Speichern/Laden von Spielständen über die App.
- Deployment-Sonderfälle (Minefields, Hidden Units, Artillery-Auto-Hit,
  Force-/C3-Netzwerke, Trailer/Train) werden von der Bridge nicht übersetzt.
- Alle `CFR_*`-Client-Feedback-Requests (z. B. AMS-Zuweisung, TAG-Ziel) werden
  in der Bridge nicht beantwortet — abhängig von Server-Timeout-Verhalten kann
  das eine Runde blockieren, falls ein solcher Fall eintritt.

## Konventionen

- **Commits**: kurzer Imperativ-Titel, `bridge:`/`mobile:`/`docs:`-Präfix wo
  sinnvoll (z. B. `bridge: add entity DTO mapping for ENTITY_UPDATE`).
- **Neue Packet-Typen in der Bridge ergänzen**: (1) DTO in `bridge/.../dto/`
  hinzufügen, (2) Mapping-Methode in `PacketTranslator`/`GameStateMapper`
  ergänzen, (3) Unit-Test in `bridge/src/test/.../PacketTranslatorTest.java`,
  (4) Zeile in der Tabelle in `docs/protocol-notes.md` ergänzen, (5) bei
  Breaking Change: `schemaVersion` in `docs/decisions.md` #3 erhöhen.
- **JSON-Schema-Versionierung**: `schemaVersion`-Feld in jeder WS-Nachricht,
  siehe `docs/decisions.md` #3.
- **Code-Style Bridge**: folgt MegaMeks `.editorconfig`/Checkstyle-Konventionen
  so weit sinnvoll (4 Spaces, keine Tabs), aber eigenes, kleineres Checkstyle-
  Profil in `bridge/config/checkstyle.xml` (kein Zwang zu MegaMeks vollem
  Regelwerk).
- **Code-Style Mobile**: Standard `dart format` + `flutter_lints`.

## Rechtliches

MegaMek-Code: GPL-3.0-or-later. MegaMek-Daten/Assets: CC-BY-NC-4.0. Details
und Konsequenzen für dieses Repo: `docs/licensing.md`. Dieses Projekt ist ein
inoffizielles Fan-Tool, nicht mit Catalyst Game Labs/Microsoft/MegaMek-Team
affiliiert.
