import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/game_state_snapshot.dart';
import '../../../state/game_session.dart';

/// Lobby sub-panel: browse and pick the board for the match. The board list
/// comes from the server (`Game.getMapSettings()`), grouped by the folder the
/// map lives in, with a text filter.
class MapSelectPanel extends ConsumerStatefulWidget {
  const MapSelectPanel({super.key, required this.snapshot});

  final GameStateSnapshot snapshot;

  @override
  ConsumerState<MapSelectPanel> createState() => _MapSelectPanelState();
}

class _MapSelectPanelState extends ConsumerState<MapSelectPanel> {
  String _filter = '';

  static (String folder, String name) split(String board) {
    final trimmed = board.startsWith('/') ? board.substring(1) : board;
    final i = trimmed.lastIndexOf('/');
    if (i < 0) {
      return ('Other', trimmed);
    }
    return (trimmed.substring(0, i), trimmed.substring(i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selected = snapshot.selectedBoards.firstOrNull;
    final query = _filter.toLowerCase();
    final groups = <String, List<String>>{};
    for (final board in snapshot.availableBoards) {
      final (folder, name) = split(board);
      if (query.isNotEmpty &&
          !name.toLowerCase().contains(query) &&
          !folder.toLowerCase().contains(query)) {
        continue;
      }
      groups.putIfAbsent(folder, () => []).add(board);
    }
    final folders = groups.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: TextField(
            key: const Key('map-filter'),
            decoration: const InputDecoration(
              labelText: 'Filter maps (e.g. desert, hills, 16x17)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selected == null
                  ? 'No map selected yet.'
                  : 'Selected: ${split(selected).$2} (${split(selected).$1})',
              key: const Key('selected-map'),
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final folder in folders)
                ExpansionTile(
                  key: PageStorageKey('folder-$folder-${query.isNotEmpty}'),
                  initiallyExpanded:
                      query.isNotEmpty || groups[folder]!.contains(selected),
                  title: Text(folder),
                  subtitle: Text('${groups[folder]!.length} maps'),
                  children: [
                    for (final board in groups[folder]!)
                      ListTile(
                        key: Key('map-$board'),
                        dense: true,
                        selected: board == selected,
                        leading: Icon(
                          board == selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(split(board).$2),
                        onTap: () => ref
                            .read(gameSessionProvider.notifier)
                            .sendSelectBoard([board]),
                      ),
                  ],
                ),
              if (folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No maps match.')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
