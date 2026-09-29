import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/game_state_snapshot.dart';
import '../../../state/game_session.dart';
import 'mech_catalog_sheet.dart';

/// Lobby sub-panel: add Princess AI opponents and their mechs. Bot players
/// flow through the same `players`/`entities` snapshot fields as humans (see
/// `Player.bot`), so this just filters the existing snapshot rather than
/// tracking any separate bot state client-side.
class BotSetupPanel extends ConsumerWidget {
  const BotSetupPanel({super.key, required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bots = snapshot.players.where((p) => p.bot).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bots.length,
            itemBuilder: (context, index) {
              final bot = bots[index];
              final unitCount = snapshot.units
                  .where((u) => u.ownerId == bot.id)
                  .length;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.smart_toy),
                  title: Text(bot.name),
                  subtitle: Text('$unitCount mech${unitCount == 1 ? '' : 's'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add mech',
                    onPressed: () => _openCatalog(context, bot.name),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Bot'),
            onPressed: () => _addBot(context, ref),
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

  Future<void> _addBot(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bot'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Bot name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(gameSessionProvider.notifier).sendAddBot(name);
    }
  }
}
