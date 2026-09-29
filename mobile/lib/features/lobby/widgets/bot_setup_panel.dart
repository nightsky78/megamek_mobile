import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/game_state_snapshot.dart';
import '../../../state/game_session.dart';
import 'force_panel.dart';
import 'mech_catalog_sheet.dart';

const botDifficulties = <(String, String, String)>[
  ('easy', 'Easy', 'Cautious, retreats early'),
  ('normal', 'Normal', 'Balanced default behaviour'),
  ('hard', 'Hard', 'Ruthless, focuses fire'),
  ('berserk', 'Berserk', 'Charges straight in'),
];

/// Lobby sub-panel: add Princess AI opponents (with a difficulty preset) and
/// fill their rosters. Bot players flow through the same `players`/`entities`
/// snapshot fields as humans (see `Player.bot`).
class BotSetupPanel extends ConsumerWidget {
  const BotSetupPanel({super.key, required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bots = snapshot.players.where((p) => p.bot).toList();

    return Column(
      children: [
        Expanded(
          child: bots.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No opponents yet. Add a bot, then give it some units.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: bots.length,
                  itemBuilder: (context, index) {
                    final bot = bots[index];
                    final unitCount = snapshot.units
                        .where((u) => u.ownerId == bot.id)
                        .length;
                    return Card(
                      key: ValueKey('bot-${bot.name}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.smart_toy),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bot.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Team ${bot.team} · $unitCount unit${unitCount == 1 ? '' : 's'} · BV ${bot.bv}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  key: Key('add-bot-unit-${bot.name}'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Units'),
                                  onPressed: () =>
                                      _openCatalog(context, bot.name),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ForceList(snapshot: snapshot, player: bot),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const Key('add-bot'),
            icon: const Icon(Icons.add),
            label: const Text('Add bot'),
            onPressed: () => _addBot(context, ref, bots.length + 1),
          ),
        ),
      ],
    );
  }

  void _openCatalog(BuildContext context, String botName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MechCatalogSheet(targetBotName: botName),
    );
  }

  Future<void> _addBot(BuildContext context, WidgetRef ref, int index) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _AddBotDialog(defaultName: 'Bot$index'),
    );
    if (result != null && result.$1.isNotEmpty) {
      ref
          .read(gameSessionProvider.notifier)
          .sendAddBot(result.$1, difficulty: result.$2);
    }
  }
}

class _AddBotDialog extends StatefulWidget {
  const _AddBotDialog({required this.defaultName});

  final String defaultName;

  @override
  State<_AddBotDialog> createState() => _AddBotDialogState();
}

class _AddBotDialogState extends State<_AddBotDialog> {
  late final _name = TextEditingController(text: widget.defaultName);
  String _difficulty = 'normal';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add bot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('bot-name'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Bot name'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final d in botDifficulties)
                ChoiceChip(
                  key: Key('difficulty-${d.$1}'),
                  label: Text(d.$2),
                  selected: _difficulty == d.$1,
                  onSelected: (_) => setState(() => _difficulty = d.$1),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            botDifficulties.firstWhere((d) => d.$1 == _difficulty).$3,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('bot-add-confirm'),
          onPressed: () =>
              Navigator.of(context).pop((_name.text.trim(), _difficulty)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
