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
///
/// While the socket is down but a snapshot exists ([GameSessionState.isLive])
/// the last known screen stays up with a reconnect banner on top.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(gameSessionProvider.notifier).resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);

    ref.listen<int>(gameSessionProvider.select((s) => s.noticeSeq), (_, _) {
      final notice = ref.read(gameSessionProvider).notice;
      if (notice != null && mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      }
    });

    if (!session.isLive || session.snapshot == null) {
      _preferPortrait();
      return const ConnectScreen();
    }

    final phase = session.snapshot!.phase;
    final Widget screen;
    if (phase == 'LOUNGE') {
      _preferPortrait();
      screen = const LobbyScreen();
    } else {
      // Phase 3: "Landscape als primäre Ausrichtung für die Map" - preferred,
      // not locked, so a player who prefers portrait can still use it.
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
      screen = const GameScreen();
    }

    final status = session.status;
    if (status is! Reconnecting) {
      return screen;
    }
    return Stack(
      children: [
        screen,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.orange.shade800,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  key: const Key('reconnect-banner'),
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Reconnecting... (attempt ${status.attempt})',
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(gameSessionProvider.notifier).retryNow(),
                      child: const Text('Retry now'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _preferPortrait() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}
