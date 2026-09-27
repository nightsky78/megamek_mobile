# Architekturentscheidungen (ADR-Kurzform)

Kurzformat: **Entscheidung / Begründung / Konsequenz**. Chronologisch, neueste
zuerst ergänzen.

## 1. MegaMek + mm-data als Git-Submodule, gepinnt auf `master`-Commit statt Release-Tag

MegaMek ist unter `vendor/megamek` eingebunden, `mm-data` unter `vendor/mm-data`
(exakt das von MegaMeks eigenem `settings.gradle` erwartete Sibling-Layout:
`includeBuild('../mm-data')`). Beide sind read-only Referenzen (Submodule =
Commit-Pointer, kein Code-Kopieren).

Gepinnt wurde der `master`-HEAD zum RechercheZeitpunkt
(`f02023f9aeb8799881d7a8527ddf4fe0f9919d47` bzw. für mm-data
`e80f64adab1e630ef0d44fe59df90af29f5e3b18`), **nicht** der neueste Release-Tag
(`v0.51.00.1`). Grund: `megamek.client.HeadlessClient` und
`megamek.client.ui.clientGUI.CommanderGUI` (die im Auftrag erwähnte PR #6418,
"Headless client, Commander GUI") sind zum Zeitpunkt der Recherche nur auf
`master` vorhanden, nicht im letzten Release. Da die Bridge genau auf
`HeadlessClient` aufbaut, ist der aktuelle `master`-Stand die einzig sinnvolle
Basis. Konsequenz: Die Bridge muss beim Aktualisieren des Submodules geprüft
werden (MegaMek entwickelt sich schnell); ein Upgrade auf einen späteren
Release-Tag, sobald dieser `HeadlessClient` enthält, ist die empfohlene
Folgearbeit für mehr Stabilität.

## 2. Bridge-Framework: Javalin statt Ktor/Spring WebFlux

Javalin (reines Java, kein zusätzlicher Kotlin-Toolchain-Bedarf, minimaler
Overhead über eingebettetem Jetty) passt am besten zu einem Java-Modul, das
MegaMeks Java-Client-Klassen 1:1 einbindet. Ktor hätte eine Kotlin-Java-Interop-
Schicht erzwungen; Spring WebFlux ist für diesen kleinen Scope (eine
WebSocket-Route, ein paar REST-Endpunkte) deutlich zu schwergewichtig
(Autoconfig, DI-Container, längere Startzeit). Javalin bietet WebSocket-Support
"out of the box" (`app.ws("/ws", ...)`) und lässt sich ohne Codegen mit Jackson
(ohnehin MegaMek-Dependency) für JSON verbinden.

## 3. JSON statt roher Java-Serialisierung; eigene DTOs statt MegaMek-Objekte

Siehe `docs/protocol-notes.md`. Zusätzlich: jede WebSocket-Nachricht trägt ein
`type`-Feld (Discriminator) und die Zustands-Snapshots ein `schemaVersion`
(aktuell `1`). Breaking Changes am Schema erhöhen `schemaVersion`; die Bridge
akzeptiert nur Action-Nachrichten mit passender oder fehlender Versionsangabe
(fehlend = `1` angenommen, für einfache erste Mobile-Client-Versionen).
Neue Packet-Typen werden nach dem in `CLAUDE.md` beschriebenen Muster ergänzt:
DTO hinzufügen → Mapper-Methode in `PacketTranslator` → Test in
`PacketTranslatorTest` → Eintrag in dieser Tabelle/README.

## 4. Ein Bridge-Prozess pro MegaMek-Server-Verbindung, mehrere Mobile-Clients pro Bridge

Die Bridge verbindet sich **einmal** als ein einziger MegaMek-Client mit dem
Server (ein Login = ein Player-Slot). Mehrere Mobile-Geräte können sich mit
derselben Bridge-Instanz per WebSocket verbinden und sehen denselben
Spielzustand (z. B. ein Spieler mit Handy + Tablet gleichzeitig, oder
Zuschauer). Für "zwei Spieler, zwei MegaMek-Clients" (Abnahmekriterium) werden
**zwei Bridge-Instanzen** gestartet (je ein Docker-Container/Prozess, je ein
`PLAYER_NAME`/Port), die sich beide mit demselben Server verbinden — genau wie
zwei Desktop-Clients das auch täten. Das hält die Bridge selbst zustandslos
bezüglich "wie viele Spieler", was Testen/Deployment vereinfacht.

## 5. MegaMek-Server im Docker-Compose: offizielles Release-Artefakt, nicht In-Container-Gradle-Build

Der dedizierte Server läuft im Docker-Setup aus dem offiziellen MegaMek-Release
(`MegaMek-<version>.zip` von GitHub Releases, per Dockerfile heruntergeladen
und mit `startServer.sh` / `-dedicated`-Flag gestartet), **nicht** aus einem
In-Container-Gradle-Build von `vendor/megamek`. Begründung: Der Server soll per
Auftrag "unverändert" laufen — das offizielle, von MegaMek selbst gebaute und
getestete Artefakt ist die getreueste Umsetzung von "unverändert", und erspart
den ~1,7 GB großen `mm-data`-Sync sowie lange Gradle-Buildzeiten im
Server-Image. Die Bridge dagegen *muss* MegaMeks Java-Quellcode als
Compile-Dependency einbinden (Auftrag: "bestehende Client-Klassen
wiederverwenden") und wird daher aus `vendor/megamek` heraus gebaut (Gradle
Composite Build) — dort ist ein Sourcecode-Build unumgänglich.

**Versionskopplung**: Das Server-Release im Dockerfile und der
`vendor/megamek`-Submodule-Commit müssen dieselbe MegaMek-Version sprechen
(siehe Protokoll-Notiz zu `SERVER_VERSION_CHECK` — bei Mismatch verweigert der
Server die Verbindung). Solange kein passender Release-Tag mit
`HeadlessClient` existiert (siehe Entscheidung 1), wird das Server-Image daher
**ebenfalls aus `vendor/megamek`-Quellcode gebaut** (Multi-Stage-Dockerfile),
bis ein offizieller Release-Tag verfügbar ist, der zu unserem Submodule-Commit
passt — dann kann auf das schnellere Release-Zip umgestellt werden. Dieser
Kompromiss ist in `docker/megamek-server/Dockerfile` kommentiert.

## 6. Flutter State-Management: Riverpod

`flutter_riverpod` statt BLoC/Provider/GetX: kompilierzeitsichere DI ohne
`BuildContext`-Abhängigkeit (praktisch für den WebSocket-Client, der
unabhängig vom Widget-Baum lebt und Zustand pushen muss), gute Testbarkeit,
und geringe Boilerplate für die überschaubare Anzahl an Providern, die dieses
MVP braucht (`connectionProvider`, `gameStateProvider`, `selectedUnitProvider`,
`chatProvider`).

## 7. Hex-Map-Rendering: `CustomPainter` statt Fertig-Paket

Eigener `CustomPainter` auf `Canvas` (wie im Auftrag vorgeschlagen) statt eines
Hex-Grid-Pakets von pub.dev: MegaMeks Koordinatensystem (Doppelte
Spalten-Offsets, `Coords`-Klasse) ist speziell genug, dass ein generisches
Hex-Paket keine Zeit sparen würde, und wir behalten volle Kontrolle über
Pan/Zoom-Performance und Tap-Hit-Testing gegen Server-Koordinaten.

## 8. Kommunikationsprotokoll Bridge↔Mobile: WebSocket, ein Kanal, JSON-Envelope

Ein einziger WebSocket (`/ws?player=<name>`) statt REST+Polling: passt zum
Server-Push-Charakter des Spiels (Server treibt Zustandsänderungen,
Mobile-Client reagiert). Envelope: `{"type": "...", "schemaVersion": 1, "payload": {...}}`.
REST bleibt nur für zustandslose Dinge (`GET /health`, `GET /games` für die
Lobby-Übersicht vor dem WebSocket-Connect).
