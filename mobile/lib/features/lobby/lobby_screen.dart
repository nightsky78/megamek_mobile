import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/game_state_snapshot.dart';
import '../../core/models/player.dart';
import '../../state/game_session.dart';
import '../game/widgets/chat_panel.dart';
import 'widgets/bot_setup_panel.dart';
import 'widgets/map_select_panel.dart';
import 'widgets/mech_catalog_sheet.dart';

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
              LobbySetupStep.roster => _RosterBody(snapshot: snapshot),
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
            itemBuilder: (context, index) =>
                _PlayerTile(player: snapshot.players[index]),
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

class _RosterBody extends ConsumerWidget {
  const _RosterBody({required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUnits = snapshot.units
        .where((u) => u.ownerId == snapshot.localPlayerId)
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: myUnits.length,
            itemBuilder: (context, index) {
              final unit = myUnits[index];
              return Card(
                child: ListTile(
                  title: Text(unit.displayName),
                  subtitle: Text('Armor ${unit.armor}/${unit.totalArmor}'),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Mech'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => const MechCatalogSheet(),
            ),
          ),
        ),
      ],
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
        leading: CircleAvatar(
          child: player.bot
              ? const Icon(Icons.smart_toy)
              : Text(player.team.toString()),
        ),
        title: Text(player.name),
        subtitle: Text(
          'Team ${player.team}${player.gameMaster ? " · Game Master" : ""}',
        ),
        trailing: Icon(
          player.done ? Icons.check_circle : Icons.hourglass_empty,
          color: player.done ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}
