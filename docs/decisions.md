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

## 5. MegaMek-Server im Docker-Compose: aus Quellcode gebaut (Multi-Stage-Dockerfile), nicht aus einem Release-Artefakt

Ursprünglich war geplant, den dedizierten Server aus dem offiziellen
MegaMek-Release-Zip zu ziehen (kein eigener Gradle-Build im Server-Image
nötig). Das setzt aber einen Release-Tag voraus, der dieselbe MegaMek-Version
spricht wie die Bridge — sonst lehnt `SERVER_VERSION_CHECK` die
Bridge-Verbindung ab (siehe `docs/protocol-notes.md`). Da `HeadlessClient`
(worauf die Bridge aufbaut, siehe Entscheidung 1) zum Recherchezeitpunkt nur
auf `master` existiert und in keinem Release-Tag enthalten ist, gibt es kein
passendes Release-Artefakt. `docker/megamek-server/Dockerfile` baut den
Server daher **ebenfalls per Multi-Stage-Build aus `vendor/megamek`-Quellcode**
(`./gradlew :megamek:installDist`, derselbe Submodule-Commit wie die Bridge)
— das ist die einzige Möglichkeit, garantiert dieselbe Version wie die Bridge
zu haben, und bleibt trotzdem "unverändert" im Sinne des Auftrags: kein
einziges MegaMek-Quellfile wird angefasst, nur kompiliert. Sobald ein
offizieller Release-Tag mit `HeadlessClient` erscheint, kann auf das
schnellere Release-Zip umgestellt werden (Kompromiss im Dockerfile
kommentiert).

Das Server-Image *braucht* die echten `mm-data`-Inhalte zur Laufzeit (Karten,
Einheiten-Definitionen) und stößt sie über `installDist`s volle Sync-Tasks an
— anders als die Bridge (siehe Entscheidung 10).

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

## 9. Repo-Root-Gradle-Wrapper auf Gradle 9.4.1 gepinnt (nicht die vorinstallierte 8.14.3)

`vendor/megamek/gradle/wrapper/gradle-wrapper.properties` verlangt Gradle 9.4.1
(Palantir-git-version-, Launch4j- und Sentry-Gradle-Plugins in der dort
verwendeten Version brauchen dessen APIs). Ein Composite Build (unser
Root-`settings.gradle` mit `includeBuild('vendor/megamek')`) läuft immer mit
**einer** Gradle-Version für den gesamten Build, bestimmt vom Root-Wrapper —
die 8.14.3, die in diesem Environment vorinstalliert war, reicht dafür nicht.
Deshalb wurde am Repo-Root ein eigener Wrapper auf 9.4.1 erzeugt
(`./gradlew wrapper --gradle-version 9.4.1`, ausgeführt mit der von MegaMeks
eigenem Wrapper-Download bereits vorhandenen Distribution). Build-Befehle im
gesamten Projekt gehen über dieses Root-`./gradlew`, nie über ein
`vendor/megamek/gradlew` direkt.

## 10. Megamek-Server-Docker-Image: verifiziert, dass `mm-data`-Sync-Tasks nicht am Compile-Pfad hängen

Während der Bridge-Implementierung wurde geprüft, dass `:megamek:megamek:jar`
(und damit `:bridge:compileJava`) erfolgreich durchläuft, **ohne** dass
`mm-data`s Sync-Tasks (`stageDataFiles` etc., siehe Entscheidung 5) je
ausgeführt werden — `processResources` hängt nicht daran. Für die Bridge
selbst (die nur Netzwerk-/Modellklassen braucht, keine Mek-/Kartendaten)
genügt daher ein `vendor/mm-data`-Submodule-Checkout ohne besondere
Sparse-Checkout-Behandlung; der Server (Entscheidung 5) braucht die echten
Daten dagegen zur Laufzeit (Karten, Einheiten) und bekommt sie über
`installDist`, das die vollen Sync-Tasks anstößt.

## 12. Bekannte Eigenheit: MegaMeks Server-Konsolen-Log wirkt "eingefroren", ist es aber nicht

Beim manuellen Testen von `bin/megamek -dedicated -port ...` (sowohl über
`gradle run` als auch direkt) erscheinen nach den ersten vier
Log4j-Initialisierungszeilen minutenlang **keine weiteren Konsolenzeilen**,
obwohl der Server in Wahrheit bereits vollständig hochgefahren ist und Port
2346 sofort TCP-Verbindungen annimmt (mit `jstack` verifiziert: der
"Connection Listener"-Thread steckt in `ServerSocket.accept()`, der Server
wartet also aktiv auf Clients). Alle weiteren Log-Zeilen (inkl. der
erwarteten "s: listening for clients...") erscheinen erst gebündelt beim
Prozessende. Das liegt an MegaMeks eigener `mmconf/log4j2.xml`-Konfiguration
(deren `bufferSize is set to 8192 but bufferedIO is not true`-Warnung schon
auf eine Inkonsistenz hindeutet), nicht an der Bridge oder am Docker-Setup.

**Konsequenz**: Ein leeres/wirkendes-eingefrorenes `docker logs
megamek-server` unmittelbar nach dem Start ist normal und kein Fehlersignal
— den tatsächlichen Serverstatus per TCP-Verbindungsversuch prüfen
(`nc -z localhost 2346` bzw. der Bridge-eigene Connect-Versuch), nicht per
Log-Beobachtung.

## 11. UTF-8-Locale ist Pflicht zum Bauen (`LANG=C.UTF-8`)

`vendor/mm-data` enthält mindestens einen nicht-ASCII-Dateinamen
(`data/images/units/meks/Götterdämmerung.png`). Läuft Gradle/JVM unter einer
POSIX/C-Locale ohne UTF-8 (`sun.jnu.encoding` fällt dann auf ASCII zurück),
kann `stageDataImages` diese Datei nicht einmal hashen ("No such file or
directory", obwohl die Datei existiert — nur ihr Name wird falsch dekodiert).
Getroffen und reproduziert während der Entwicklung in einer Umgebung mit
`LANG=` (leer)/`LC_ALL=` (leer). Fix: `LANG=C.UTF-8 LC_ALL=C.UTF-8` vor jedem
Gradle-Aufruf, der `vendor/mm-data` anfasst (im Server-Dockerfile per `ENV`
gesetzt; lokal einmalig exportieren oder der Shell-Umgebung hinzufügen).

## 8. Kommunikationsprotokoll Bridge↔Mobile: ein WebSocket-Kanal, flache JSON-Nachrichten

Ein einziger WebSocket (`/ws`) statt REST+Polling: passt zum
Server-Push-Charakter des Spiels (Server treibt Zustandsänderungen,
Mobile-Client reagiert). Jede Nachricht ist ein **flaches** JSON-Objekt mit
`"type"` und `"schemaVersion"` auf oberster Ebene (kein verschachteltes
`payload`-Feld — einfacher in Jackson-Records abzubilden und einfacher im
Dart-Client zu parsen). Siehe `bridge/README.md` für alle Nachrichtentypen.
REST bleibt nur für zustandslose Dinge (`GET /health`). Es gibt bewusst
**keinen** `/games`-Lobby-Endpunkt: ein Bridge-Prozess bedient genau einen
MegaMek-Server/Player-Slot (Entscheidung 4) und verbindet sich beim Start
automatisch — die Mobile-App wählt "welcher Server" über Host/Port der
*Bridge* selbst (Connect-Screen, Phase 2), nicht über eine von der Bridge
angebotene Serverliste.
