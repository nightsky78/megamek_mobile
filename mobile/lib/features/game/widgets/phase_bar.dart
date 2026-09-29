import 'package:flutter/material.dart';

import '../../../core/models/game_state_snapshot.dart';

/// Always-visible top bar: phase, round, and the "Done"/"Next" button
/// (Phase 2: "Phasenanzeige + Weiter-Button").
class PhaseBar extends StatelessWidget implements PreferredSizeWidget {
  const PhaseBar({
    super.key,
    required this.snapshot,
    required this.isLocalPlayerDone,
    required this.onEndPhase,
    required this.onOpenUnits,
    required this.onOpenChat,
  });

  final GameStateSnapshot snapshot;
  final bool isLocalPlayerDone;
  final VoidCallback onEndPhase;
  final VoidCallback onOpenUnits;
  final VoidCallback onOpenChat;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text('${snapshot.phaseLabel} · Round ${snapshot.round}'),
      actions: [
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
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: FilledButton(
              onPressed: onEndPhase,
              child: Text(isLocalPlayerDone ? 'Waiting...' : 'Done'),
            ),
          ),
        ),
      ],
    );
  }
}
