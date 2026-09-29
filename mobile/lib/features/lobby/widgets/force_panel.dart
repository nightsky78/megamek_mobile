import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/game_state_snapshot.dart';
import '../../../core/models/player.dart';
import '../../../core/models/unit.dart';
import '../../../state/game_session.dart';
import 'mech_catalog_sheet.dart';

/// Force management for one player: the units on the roster with their BV and
/// pilot skills, plus remove / edit-pilot / add-more. Used for the local
/// player ("My Mechs" tab) and, embedded, for each bot.
class ForceList extends ConsumerWidget {
  const ForceList({super.key, required this.snapshot, required this.player});

  final GameStateSnapshot snapshot;
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = snapshot.units.where((u) => u.ownerId == player.id).toList();
    if (units.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No units yet.', style: TextStyle(color: Colors.white60)),
      );
    }
    return Column(
      children: [
        for (final unit in units)
          _UnitTile(unit: unit, key: ValueKey('force-${unit.id}')),
      ],
    );
  }
}

class _UnitTile extends ConsumerWidget {
  const _UnitTile({super.key, required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        title: Text(unit.displayName),
        subtitle: Text(
          '${unit.tons.toStringAsFixed(0)} t · BV ${unit.bv} · '
          'pilot ${unit.gunnery}/${unit.piloting}',
        ),
        onTap: () => _editPilot(context, ref),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(gameSessionProvider.notifier).sendRemoveUnit(unit.id),
        ),
      ),
    );
  }

  Future<void> _editPilot(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) =>
          _PilotDialog(gunnery: unit.gunnery, piloting: unit.piloting),
    );
    if (result != null) {
      ref
          .read(gameSessionProvider.notifier)
          .sendSetPilot(
            entityId: unit.id,
            gunnery: result.$1,
            piloting: result.$2,
          );
    }
  }
}

class _PilotDialog extends StatefulWidget {
  const _PilotDialog({required this.gunnery, required this.piloting});

  final int gunnery;
  final int piloting;

  @override
  State<_PilotDialog> createState() => _PilotDialogState();
}

class _PilotDialogState extends State<_PilotDialog> {
  late int _gunnery = widget.gunnery;
  late int _piloting = widget.piloting;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilot skills'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepper('Gunnery', _gunnery, (v) => setState(() => _gunnery = v)),
          _stepper('Piloting', _piloting, (v) => setState(() => _piloting = v)),
          const Text(
            'Lower is better. 4/5 is a regular pilot.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('pilot-save'),
          onPressed: () => Navigator.of(context).pop((_gunnery, _piloting)),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _stepper(String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: 24, child: Center(child: Text('$value'))),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < 8 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// The "My Mechs" tab.
class RosterPanel extends ConsumerWidget {
  const RosterPanel({super.key, required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = snapshot.localPlayer;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (me != null) ...[
                Text(
                  '${snapshot.units.where((u) => u.ownerId == me.id).length} units · BV ${me.bv}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                ForceList(snapshot: snapshot, player: me),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const Key('add-mech'),
            icon: const Icon(Icons.add),
            label: const Text('Add units'),
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
