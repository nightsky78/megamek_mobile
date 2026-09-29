import 'package:flutter/material.dart';

import '../../../core/models/turn_models.dart';
import '../../../core/models/unit.dart';
import '../../../theme/app_theme.dart';

const _facingNames = ['N', 'NE', 'SE', 'S', 'SW', 'NW'];

String facingName(int facing) => _facingNames[facing % 6];

/// Frame shared by all turn panels: a rounded card with the unit header on
/// top and the phase-specific controls below.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.unit,
    required this.title,
    required this.onDetails,
    required this.child,
    this.trailing,
  });

  final Unit unit;
  final String title;
  final VoidCallback onDetails;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.surface.withValues(alpha: 0.97),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$title · armor ${unit.armor}/${unit.totalArmor}'
                        '${unit.heatCapacity > 0 ? ' · heat ${unit.heat}/${unit.heatCapacity}' : ''}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
                IconButton(
                  tooltip: 'Unit details',
                  icon: const Icon(Icons.info_outline),
                  onPressed: onDetails,
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class FacingControls extends StatelessWidget {
  const FacingControls({
    super.key,
    required this.facing,
    required this.onRotate,
  });

  final int facing;
  final void Function(int delta) onRotate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const Key('facing-left'),
          tooltip: 'Turn left',
          icon: const Icon(Icons.rotate_left),
          onPressed: () => onRotate(-1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Facing ${facingName(facing)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.filledTonal(
          key: const Key('facing-right'),
          tooltip: 'Turn right',
          icon: const Icon(Icons.rotate_right),
          onPressed: () => onRotate(1),
        ),
      ],
    );
  }
}

class DeployPanel extends StatelessWidget {
  const DeployPanel({
    super.key,
    required this.unit,
    required this.legalHexCount,
    required this.chosen,
    required this.facing,
    required this.onRotate,
    required this.onDeploy,
    required this.onDetails,
  });

  final Unit unit;
  final int? legalHexCount;
  final HexCoord? chosen;
  final int facing;
  final void Function(int delta) onRotate;
  final VoidCallback onDeploy;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      unit: unit,
      title: 'Deploy',
      onDetails: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            legalHexCount == null
                ? 'Loading deployment zone...'
                : chosen == null
                ? 'Tap a highlighted hex to place this unit '
                      '($legalHexCount legal hexes).'
                : 'Placing at ${chosen!.$1 + 1},${chosen!.$2 + 1}.',
            style: const TextStyle(fontSize: 13),
          ),
          if (chosen != null) ...[
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                FacingControls(facing: facing, onRotate: onRotate),
                FilledButton.icon(
                  key: const Key('deploy-confirm'),
                  icon: const Icon(Icons.check),
                  label: const Text('Deploy'),
                  onPressed: onDeploy,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MovePanel extends StatelessWidget {
  const MovePanel({
    super.key,
    required this.unit,
    required this.mode,
    required this.options,
    required this.preview,
    required this.hasDestination,
    required this.turning,
    required this.facing,
    required this.onMode,
    required this.onRotate,
    required this.onMove,
    required this.onStandStill,
    required this.onStartTurn,
    required this.onGetUp,
    required this.onCancel,
    required this.onDetails,
  });

  final Unit unit;
  final String mode;
  final MoveOptions? options;
  final MovePreview? preview;
  final bool hasDestination;
  final bool turning;
  final int facing;
  final void Function(String mode) onMode;
  final void Function(int delta) onRotate;
  final VoidCallback onMove;
  final VoidCallback onStandStill;
  final VoidCallback onStartTurn;
  final VoidCallback onGetUp;
  final VoidCallback onCancel;
  final VoidCallback onDetails;

  int get _limit => switch (mode) {
    'RUN' => unit.runMp,
    'JUMP' => unit.jumpMp,
    _ => unit.walkMp,
  };

  @override
  Widget build(BuildContext context) {
    final building = hasDestination || turning;
    return PanelCard(
      unit: unit,
      title: 'Move · MP ${unit.walkMp}/${unit.runMp}/${unit.jumpMp}',
      onDetails: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final entry in [
                ('WALK', 'Walk', true),
                ('RUN', 'Run', true),
                ('JUMP', 'Jump', unit.jumpMp > 0),
                ('BACKWARDS', 'Back', true),
              ])
                if (entry.$3)
                  ChoiceChip(
                    key: Key('mode-${entry.$1}'),
                    label: Text(entry.$2),
                    selected: mode == entry.$1,
                    onSelected: (_) => onMode(entry.$1),
                  ),
            ],
          ),
          const SizedBox(height: 6),
          if (unit.prone)
            const Text(
              'Unit is prone: it can get up, or move by crawling only where '
              'the rules allow.',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          if (!building)
            Text(
              options == null
                  ? 'Loading reachable hexes...'
                  : options!.hexes.isEmpty
                  ? 'No reachable hexes in this mode.'
                  : 'Tap a green hex to move (number = MP cost), or tap your '
                        'own hex to only turn.',
              style: const TextStyle(fontSize: 13),
            )
          else
            _preview(),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (building) ...[
                FacingControls(facing: facing, onRotate: onRotate),
                FilledButton.icon(
                  key: const Key('move-confirm'),
                  icon: const Icon(Icons.check),
                  label: Text(hasDestination ? 'Move here' : 'Turn'),
                  onPressed: hasDestination && preview?.legal != true
                      ? null
                      : onMove,
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ] else ...[
                if (unit.prone)
                  FilledButton.icon(
                    key: const Key('move-getup'),
                    icon: const Icon(Icons.accessibility_new),
                    label: const Text('Get up'),
                    onPressed: onGetUp,
                  ),
                OutlinedButton(
                  key: const Key('move-turn'),
                  onPressed: onStartTurn,
                  child: const Text('Turn in place'),
                ),
                OutlinedButton(
                  key: const Key('move-stand'),
                  onPressed: onStandStill,
                  child: const Text('Stand still'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final p = preview;
    if (!hasDestination) {
      return const Text(
        'Choose the new facing.',
        style: TextStyle(fontSize: 13),
      );
    }
    if (p == null) {
      return const Text('Computing path...', style: TextStyle(fontSize: 13));
    }
    final color = p.legal ? Colors.greenAccent : Colors.redAccent;
    return Text(
      '${p.legal ? 'Path OK' : 'Not possible'} · '
      'MP ${p.mpUsed}/$_limit'
      '${p.message != null && p.message!.isNotEmpty ? ' · ${p.message}' : ''}',
      style: TextStyle(fontSize: 13, color: color),
    );
  }
}

class FirePanel extends StatelessWidget {
  const FirePanel({
    super.key,
    required this.unit,
    required this.target,
    required this.options,
    required this.selected,
    required this.physical,
    required this.onToggle,
    required this.onFire,
    required this.onSkip,
    required this.onDetails,
    required this.onClearTarget,
  });

  final Unit unit;
  final Unit? target;
  final AttackOptions? options;
  final Set<String> selected;
  final bool physical;
  final void Function(String key) onToggle;
  final VoidCallback onFire;
  final VoidCallback onSkip;
  final VoidCallback onDetails;
  final VoidCallback onClearTarget;

  @override
  Widget build(BuildContext context) {
    final opts = options;
    final heatNow = unit.heat;
    final extraHeat = opts == null
        ? 0
        : opts.options
              .where((o) => selected.contains(o.key))
              .fold<int>(0, (a, o) => a + o.heat);
    return PanelCard(
      unit: unit,
      title: physical ? 'Physical attack' : 'Fire',
      onDetails: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (target == null)
            Text(
              physical
                  ? 'Tap an adjacent enemy to punch or kick it.'
                  : 'Tap an enemy on the map to target it.',
              style: const TextStyle(fontSize: 13),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Target: ${target!.displayName}'
                    '${opts != null ? ' · range ${opts.range}' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClearTarget,
                  child: const Text('Change'),
                ),
              ],
            ),
            if (opts == null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              )
            else if (opts.options.isEmpty)
              const Text('No attacks available against this target.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final o in opts.options) _optionTile(o)],
                ),
              ),
            if (!physical && heatNow + extraHeat > 0 && unit.heatCapacity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Heat: $heatNow +$extraHeat (capacity ${unit.heatCapacity})',
                  style: TextStyle(
                    fontSize: 12,
                    color: heatNow + extraHeat > unit.heatCapacity
                        ? Colors.orangeAccent
                        : Colors.white60,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('fire-confirm'),
                icon: Icon(
                  physical ? Icons.sports_mma : Icons.local_fire_department,
                ),
                label: Text(physical ? 'Attack' : 'Fire (${selected.length})'),
                onPressed: target == null || selected.isEmpty ? null : onFire,
              ),
              OutlinedButton(
                key: const Key('fire-skip'),
                onPressed: onSkip,
                child: Text(physical ? 'No physical attack' : 'Do not fire'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _optionTile(AttackOption o) {
    final isSelected = selected.contains(o.key);
    final subtitle = o.possible
        ? '${o.toHit != null ? 'needs ${o.toHit}+' : ''} · ${o.probability}% · '
              'dmg ${o.damage}${o.heat > 0 ? ' · heat ${o.heat}' : ''}'
        : (o.description.isEmpty ? 'not possible' : o.description);
    return ListTile(
      key: Key('option-${o.key}'),
      dense: true,
      enabled: o.possible,
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      leading: Icon(
        isSelected ? Icons.check_box : Icons.check_box_outline_blank,
        color: o.possible ? AppTheme.accent : Colors.white24,
      ),
      title: Text(o.name),
      subtitle: Text(subtitle),
      onTap: o.possible ? () => onToggle(o.key) : null,
    );
  }
}
