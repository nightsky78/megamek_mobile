# MegaMek Mobile

Play [MegaMek](https://github.com/MegaMek/megamek) (BattleTech) from a phone. A Flutter app
talks JSON over WebSocket to a small Java bridge, which joins a standard, unmodified MegaMek
server as an ordinary client. No game rules are reimplemented in the app.

```
[Flutter app] <-- WebSocket/JSON --> [Bridge (Java/Javalin)] <-- MegaMek protocol --> [MegaMek server]
```

Status: playable MVP. From the phone you can pick mechs, add a Princess bot with its own
mechs, choose a map, then play deployment, movement, firing and physical attacks through to
victory. Tested on an Android emulator against MegaMek v0.51.0; not yet on real devices or iOS.

- Architecture, build and run instructions: [CLAUDE.md](CLAUDE.md), [bridge/README.md](bridge/README.md), [mobile/README.md](mobile/README.md)
- Roadmap and decisions: [docs/roadmap.md](docs/roadmap.md), [docs/decisions.md](docs/decisions.md)

Clone with submodules (about 2 GB, only needed for bridge builds):

```bash
git submodule update --init --recursive
```

## License

GPL-3.0-or-later, see [LICENSE](LICENSE). The bridge links MegaMek code (GPL-3.0-or-later).
MegaMek game data and assets are CC-BY-NC-4.0 and are not copied into this repo. Details:
[docs/licensing.md](docs/licensing.md).

This is an unofficial fan tool, not affiliated with Catalyst Game Labs, Microsoft or the
MegaMek team. BattleTech and MechWarrior are trademarks of their respective owners.
