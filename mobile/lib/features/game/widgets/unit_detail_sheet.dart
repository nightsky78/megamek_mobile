import 'package:flutter/material.dart';

import '../../../core/models/unit.dart';
import '../../../theme/app_theme.dart';

/// Full read-out of one unit: pilot, movement, heat, per-location armor and
/// structure, weapons and ammo.
class UnitDetailSheet extends StatelessWidget {
  const UnitDetailSheet({super.key, required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(unit.displayName, style: Theme.of(context).textTheme.titleLarge),
          Text(
            '${unit.unitType} · ${unit.tons.toStringAsFixed(0)} t · BV ${unit.bv}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chip('Pilot ${unit.pilotName}'),
              _chip('Gunnery ${unit.gunnery} / Piloting ${unit.piloting}'),
              if (unit.pilotHits > 0) _chip('Pilot hits ${unit.pilotHits}'),
              _chip('MP ${unit.walkMp}/${unit.runMp}/${unit.jumpMp}'),
              if (unit.heatCapacity > 0)
                _chip('Heat ${unit.heat}/${unit.heatCapacity}'),
              if (unit.prone) _chip('Prone'),
              if (unit.shutDown) _chip('Shut down'),
              if (unit.immobile) _chip('Immobile'),
            ],
          ),
          if (unit.locations.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Armor / structure',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final l in unit.locations) _LocationRow(location: l),
          ],
          if (unit.weapons.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Weapons',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final w in unit.weapons)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  w.name,
                  style: TextStyle(
                    decoration: w.destroyed ? TextDecoration.lineThrough : null,
                    color: w.destroyed ? Colors.white38 : null,
                  ),
                ),
                subtitle: Text(
                  '${w.location} · dmg ${w.damage} · heat ${w.heat} · range ${w.rangeLabel}',
                ),
                trailing: w.usedThisRound
                    ? const Icon(Icons.bolt, size: 16)
                    : null,
              ),
          ],
          if (unit.ammo.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Ammunition',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final a in unit.ammo)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.name),
                subtitle: Text(a.location),
                trailing: Text('${a.shots}/${a.maxShots}'),
              ),
          ],
          if (unit.damagedEquipment.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Damaged equipment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final e in unit.damagedEquipment)
              Text('• $e', style: const TextStyle(color: Colors.orangeAccent)),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location});

  final UnitLocation location;

  @override
  Widget build(BuildContext context) {
    final l = location;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              l.abbr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: l.destroyed ? Colors.redAccent : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(l.armor, l.maxArmor, AppTheme.armorGood),
                const SizedBox(height: 2),
                _bar(l.internal, l.maxInternal, Colors.blueGrey),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: Text(
              l.destroyed
                  ? 'DESTROYED'
                  : 'A ${l.armor}${l.maxRearArmor > 0 ? '+${l.rearArmor}r' : ''} · I ${l.internal}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: l.destroyed ? Colors.redAccent : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(int value, int max, Color color) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: f,
        minHeight: 5,
        color: f < 0.25 ? AppTheme.armorCritical : color,
        backgroundColor: Colors.black38,
      ),
    );
  }
}
