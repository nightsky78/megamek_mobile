import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/unit_summary.dart';
import '../../../state/game_session.dart';

/// Modal bottom sheet: search MegaMek's unit database and add one to a
/// roster - the local player's own (`targetBotName == null`) or a connected
/// bot's (`targetBotName` set). Mirrors `UnitListSheet`'s
/// `DraggableScrollableSheet` + `ListView.builder` pattern, but over catalog
/// search results rather than in-game units.
class MechCatalogSheet extends ConsumerStatefulWidget {
  const MechCatalogSheet({super.key, this.targetBotName});

  final String? targetBotName;

  @override
  ConsumerState<MechCatalogSheet> createState() => _MechCatalogSheetState();
}

class _MechCatalogSheetState extends ConsumerState<MechCatalogSheet> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Populate results immediately so the sheet isn't blank on open.
    ref.read(gameSessionProvider.notifier).searchUnitCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String text) {
    ref
        .read(gameSessionProvider.notifier)
        .searchUnitCatalog(text: text.isEmpty ? null : text);
  }

  void _select(UnitSummary unit) {
    final notifier = ref.read(gameSessionProvider.notifier);
    if (widget.targetBotName == null) {
      notifier.sendAddUnit(unit.ref);
    } else {
      notifier.sendAddBotUnit(
        botName: widget.targetBotName!,
        unitRef: unit.ref,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search mechs',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${session.catalogResults.length} of ${session.catalogTotalMatches}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: session.catalogResults.length,
              itemBuilder: (context, index) {
                final unit = session.catalogResults[index];
                return Card(
                  child: ListTile(
                    title: Text('${unit.chassis} ${unit.model}'),
                    subtitle: Text(
                      '${unit.tons.toStringAsFixed(0)}t · BV ${unit.bv} · ${unit.year} · ${unit.techBase}',
                    ),
                    onTap: () => _select(unit),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
