# Lizenzfragen

## MegaMek selbst

MegaMek (und mm-data) verwenden **keine** GPL-2.0/CC-BY-NC-SA-Kombination, wie man
anhand des Projektnamens vielleicht vermuten würde. Der tatsächliche Stand
(`vendor/megamek/LICENSE`, Stand des in `vendor/megamek` gepinnten Commits) ist:

| Inhalt | Lizenz |
|---|---|
| Code (`megamek/src/megamek/**/*.java`, Build-Skripte) | **GPL-3.0-or-later** (`LICENSE.code`) |
| Spieldaten/Assets (Einheiten, Karten, Grafiken, i18n) in `megamek/data`, `megamek/docs`, `megamek/i18n`, `megamek/resources`, sowie alles in `mm-data` | **CC-BY-NC-4.0** (`LICENSE.assets`) — *nicht* NC-SA, keine Share-Alike-Pflicht |

Referenz: `vendor/megamek/LICENSE` (Übersichtsdokument), `vendor/megamek/LICENSE.code`,
`vendor/megamek/LICENSE.assets`.

## Was das für dieses Projekt bedeutet

1. **MegaMek/mm-data werden nicht kopiert.** Sie sind als Git-Submodule
   (`vendor/megamek`, `vendor/mm-data`) eingebunden — reine Commit-Referenzen,
   kein Code- oder Daten-Fork. Wer das Repo klont, zieht sie separat via
   `git submodule update --init`.
2. **`bridge/` ist eigener Code**, der MegaMek als Library-Dependency einbindet
   (Gradle Composite Build gegen `vendor/megamek`). Da die Bridge gegen
   GPL-3.0-Code linkt und MegaMek-Klassen direkt im selben JVM-Prozess nutzt
   (keine reine Netzwerk-Trennung wie bei einem separaten Serverprozess),
   muss die Bridge selbst **ebenfalls unter GPL-3.0-or-later** stehen (siehe
   `LICENSE` im Repo-Root). Das ist für ein Open-Source-Hobbyprojekt unproblematisch,
   aber wichtig für spätere Distribution/Play-Store-Fragen der App zu wissen.
3. **`mobile/` (Flutter/Dart) spricht nur JSON/WebSocket mit der Bridge**,
   linkt keinen MegaMek-Code und keine Assets. Für die App selbst besteht daher
   **keine Lizenz-Zwangskopplung an GPL-3.0** — sie kann z. B. unter MIT
   stehen. Sollten später MegaMek-Icons/Sprites/Kartendaten 1:1 in die App
   übernommen werden (z. B. Einheiten-Silhouetten), gilt für diese Assets
   CC-BY-NC-4.0: nicht-kommerzielle Nutzung, Namensnennung des MegaMek-Projekts,
   keine Share-Alike-Pflicht (im Gegensatz zur veralteten Annahme im
   Projektauftrag). Für den MVP zeichnet die App eigene, einfache Icons
   (siehe `docs/decisions.md`), um diese Frage zu umgehen.
4. **Der MegaMek-Dedicated-Server** läuft in `docker-compose.yml` unverändert
   aus dem offiziellen Quellcode/Release — keine Modifikation, keine
   Neuverteilung veränderter Server-Binaries.
5. **Namensnennung/Trademark**: MegaMek weist explizit darauf hin, dass
   BattleTech/MechWarrior-Marken Catalyst Game Labs/Microsoft gehören und
   MegaMek ein inoffizielles Fanprojekt ist. Dieses Repo übernimmt denselben
   Hinweis (siehe CLAUDE.md) und stellt sich nicht als offizielles Produkt dar.

## Offene Punkte

- Bei einer öffentlichen Veröffentlichung der App (App Store/Play Store) sollte
  `LICENSE` im Repo-Root (GPL-3.0) und ein klarer Hinweis "inoffizieller MegaMek-Client"
  in die Store-Beschreibung übernommen werden.
- CC-BY-NC-4.0 schließt kommerzielle Nutzung von aus MegaMek übernommenen
  Assets aus. Falls die App monetarisiert werden soll, dürfen keine
  MegaMek-Assets (Sprites, Kartendaten-Grafiken) übernommen werden.
