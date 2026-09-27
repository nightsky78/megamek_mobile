import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/player.dart';
import '../../state/game_session.dart';
import '../game/widgets/chat_panel.dart';

/// Portrait lobby screen (Phase 3: "Portrait für Lobby/Menüs"): who's here,
/// who's ready, and chat before the game starts. There is no "create/browse
/// games" list here on purpose - the bridge already picked one server/player
/// slot to connect to (see docs/decisions.md #8).
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final snapshot = session.snapshot!;
    final localPlayerMatches = snapshot.players.where((p) => p.id == snapshot.localPlayerId);
    final localPlayer = localPlayerMatches.isEmpty ? null : localPlayerMatches.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: snapshot.players.length,
              itemBuilder: (context, index) => _PlayerTile(player: snapshot.players[index]),
            ),
          ),
          SizedBox(
            height: 220,
            child: ChatPanel(chatLog: session.chatLog, onSend: (text) => ref.read(gameSessionProvider.notifier).sendChat(text)),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: Icon(localPlayer?.done == true ? Icons.check_circle : Icons.check_circle_outline),
                label: Text(localPlayer?.done == true ? 'Ready' : 'Mark ready'),
                onPressed: () => ref
                    .read(gameSessionProvider.notifier)
                    .sendEndPhase(done: !(localPlayer?.done ?? false)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(player.team.toString())),
        title: Text(player.name),
        subtitle: Text('Team ${player.team}${player.gameMaster ? " · Game Master" : ""}'),
        trailing: Icon(
          player.done ? Icons.check_circle : Icons.hourglass_empty,
          color: player.done ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
