import 'package:flutter/material.dart';

import '../../../core/models/game_state_snapshot.dart';

/// Always-visible top bar: phase, round, log/unit/chat shortcuts and, during
/// report phases, the Continue button that acknowledges the report.
class PhaseBar extends StatelessWidget implements PreferredSizeWidget {
  const PhaseBar({
    super.key,
    required this.snapshot,
    required this.isLocalPlayerDone,
    required this.onEndPhase,
    required this.onOpenUnits,
    required this.onOpenChat,
    required this.onOpenLog,
  });

  final GameStateSnapshot snapshot;
  final bool isLocalPlayerDone;
  final VoidCallback onEndPhase;
  final VoidCallback onOpenUnits;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenLog;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('${snapshot.phaseLabel} · Round ${snapshot.round}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.receipt_long),
          tooltip: 'Combat log',
          onPressed: onOpenLog,
        ),
        IconButton(
          icon: const Icon(Icons.list_alt),
          tooltip: 'Units',
          onPressed: onOpenUnits,
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Chat',
          onPressed: onOpenChat,
        ),
        if (snapshot.isReportPhase)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: FilledButton(
                key: const Key('continue-button'),
                onPressed: isLocalPlayerDone ? null : onEndPhase,
                child: Text(isLocalPlayerDone ? 'Waiting...' : 'Continue'),
              ),
            ),
          ),
      ],
    );
  }
}
