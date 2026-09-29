import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/game_state_snapshot.dart';
import '../../core/models/player.dart';
import '../../state/game_session.dart';
import '../game/widgets/chat_panel.dart';
import 'widgets/bot_setup_panel.dart';
import 'widgets/map_select_panel.dart';
import 'widgets/force_panel.dart';

/// Portrait lobby screen (Phase 3: "Portrait für Lobby/Menüs"): who's here,
/// who's ready, and chat before the game starts. There is no "create/browse
/// games" list here on purpose - the bridge already picked one server/player
/// slot to connect to (see docs/decisions.md #8).
///
/// Setup (roster/bots/map) is a `LobbySetupStep` chosen client-side only
/// (see `state/game_session.dart`) - `HomeShell` still picks this whole
/// screen purely from `phase == 'LOUNGE'`, per docs/decisions.md #6.
class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final snapshot = session.snapshot!;
    final step = ref.watch(lobbySetupStepProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lobby')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<LobbySetupStep>(
              segments: const [
                ButtonSegment(
                  value: LobbySetupStep.overview,
                  label: Text('Lobby'),
                ),
                ButtonSegment(
                  value: LobbySetupStep.roster,
                  label: Text('My Mechs'),
                ),
                ButtonSegment(value: LobbySetupStep.bots, label: Text('Bots')),
                ButtonSegment(value: LobbySetupStep.map, label: Text('Map')),
              ],
              selected: {step},
              onSelectionChanged: (selection) => ref
                  .read(lobbySetupStepProvider.notifier)
                  .select(selection.first),
            ),
          ),
          Expanded(
            child: switch (step) {
              LobbySetupStep.overview => _OverviewBody(
                session: session,
                snapshot: snapshot,
              ),
              LobbySetupStep.roster => RosterPanel(snapshot: snapshot),
              LobbySetupStep.bots => BotSetupPanel(snapshot: snapshot),
              LobbySetupStep.map => MapSelectPanel(snapshot: snapshot),
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({required this.session, required this.snapshot});

  final GameSessionState session;
  final GameStateSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPlayerMatches = snapshot.players.where(
      (p) => p.id == snapshot.localPlayerId,
    );
    final localPlayer = localPlayerMatches.isEmpty
        ? null
        : localPlayerMatches.first;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.players.length,
            itemBuilder: (context, index) => _PlayerTile(
              player: snapshot.players[index],
              isLocal: snapshot.players[index].id == snapshot.localPlayerId,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ChatPanel(
            chatLog: session.chatLog,
            onSend: (text) =>
                ref.read(gameSessionProvider.notifier).sendChat(text),
          ),
        ),
        Padding(
          // Bottom inset applied manually rather than via SafeArea: in manual
          // testing, wrapping this row in SafeArea(top: false, ...) left the
          // buttons visually in place but silently untappable (hit-testing
          // stopped matching the rendered position) after the app had shown
          // and dismissed the on-screen keyboard elsewhere in the session -
          // reproduced repeatedly, including across full app restarts, and
          // resolved every time by dropping SafeArea in favor of reading the
          // bottom padding directly.
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: Icon(
                    localPlayer?.done == true
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    localPlayer?.done == true ? 'Ready' : 'Mark ready',
                  ),
                  onPressed: () => ref
                      .read(gameSessionProvider.notifier)
                      .sendEndPhase(done: !(localPlayer?.done ?? false)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Game'),
                  onPressed: () =>
                      ref.read(gameSessionProvider.notifier).sendStartGame(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerTile extends ConsumerWidget {
  const _PlayerTile({required this.player, required this.isLocal});

  final Player player;
  final bool isLocal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: player.bot
              ? const Icon(Icons.smart_toy)
              : const Icon(Icons.person),
        ),
        title: Text(player.name + (isLocal ? ' (you)' : '')),
        subtitle: Text(
          'Team ${player.team} - BV ${player.bv}'
          '${player.gameMaster ? " - Game Master" : ""}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLocal || player.bot)
              PopupMenuButton<int>(
                key: Key('team-${player.name}'),
                tooltip: 'Change team',
                icon: const Icon(Icons.groups),
                onSelected: (team) => ref
                    .read(gameSessionProvider.notifier)
                    .sendSetTeam(
                      team: team,
                      botName: player.bot ? player.name : null,
                    ),
                itemBuilder: (context) => [
                  for (var team = 1; team <= 4; team++)
                    PopupMenuItem(value: team, child: Text('Team $team')),
                ],
              ),
            Icon(
              player.done ? Icons.check_circle : Icons.hourglass_empty,
              color: player.done ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
