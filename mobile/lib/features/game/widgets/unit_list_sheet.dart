import 'package:flutter/material.dart';

import '../../../core/models/unit.dart';

/// Modal bottom sheet: full unit roster (Phase 2: "Einheiten-Liste"; Phase 3:
/// one focused sheet instead of a permanent side panel).
class UnitListSheet extends StatelessWidget {
  const UnitListSheet({
    super.key,
    required this.units,
    required this.localPlayerId,
    required this.onSelect,
  });

  final List<Unit> units;
  final int? localPlayerId;
  final void Function(Unit unit) onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: units.length,
        itemBuilder: (context, index) {
          final unit = units[index];
          final isMine = unit.ownerId == localPlayerId;
          return Card(
            child: ListTile(
              leading: Icon(
                unit.destroyed ? Icons.block : Icons.smart_toy,
                color: isMine ? Colors.lightBlueAccent : Colors.redAccent,
              ),
              title: Text(unit.displayName),
              subtitle: Text(
                unit.destroyed
                    ? 'Destroyed'
                    : 'Armor ${unit.armor}/${unit.totalArmor} · ${unit.pilotName}',
              ),
              onTap: unit.destroyed
                  ? null
                  : () {
                      onSelect(unit);
                      Navigator.of(context).pop();
                    },
            ),
          );
        },
      ),
    );
  }
}
