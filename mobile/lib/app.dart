import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/connect/connect_screen.dart';
import 'features/game/game_screen.dart';
import 'features/lobby/lobby_screen.dart';
import 'state/game_session.dart';
import 'theme/app_theme.dart';

class MegaMekMobileApp extends StatelessWidget {
  const MegaMekMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MegaMek Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeShell(),
    );
  }
}

/// Picks Connect / Lobby / Game purely from session state, instead of a
/// named-route stack: there is exactly one meaningful "current screen" at any
/// time, driven by the bridge's own state (see docs/decisions.md #6).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);

    if (session.status is! Connected || session.snapshot == null) {
      _preferPortrait();
      return const ConnectScreen();
    }

    final phase = session.snapshot!.phase;
    if (phase == 'LOUNGE') {
      _preferPortrait();
      return const LobbyScreen();
    }
    // Phase 3: "Landscape als primäre Ausrichtung für die Map" - preferred,
    // not locked, so a player who prefers portrait can still use it.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    return const GameScreen();
  }

  void _preferPortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
