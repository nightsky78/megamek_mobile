import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/game_state_snapshot.dart';
import '../../../state/game_session.dart';

/// Lobby sub-panel: pick the board for the match. `availableBoards` comes
/// from the server (`Game.getMapSettings()`), not scanned client-side - see
/// bridge/README.md.
class MapSelectPanel extends ConsumerStatefulWidget {
  const MapSelectPanel({super.key, required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  ConsumerState<MapSelectPanel> createState() => _MapSelectPanelState();
}

class _MapSelectPanelState extends ConsumerState<MapSelectPanel> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.snapshot.selectedBoards.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.snapshot.availableBoards;

    return Column(
      children: [
        Expanded(
          child: RadioGroup<String>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: available.length,
              itemBuilder: (context, index) {
                final board = available[index];
                return RadioListTile<String>(title: Text(board), value: board);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _selected == null
                ? null
                : () => ref.read(gameSessionProvider.notifier).sendSelectBoard([
                    _selected!,
                  ]),
            child: const Text('Use this board'),
          ),
        ),
      ],
    );
  }
}
