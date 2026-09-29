import 'package:flutter/material.dart';

import '../../../core/models/actions.dart';
import '../../../core/models/unit.dart';
import '../../../theme/app_theme.dart';

/// Bottom action panel: whatever the selected unit can do in the current
/// phase, always at the bottom edge with >=44pt touch targets (Phase 3:
/// "Long-Press/kontextsensitive Action-Buttons am unteren Rand statt
/// Rechtsklick-Menüs"). Deliberately step-button based rather than
/// tap-a-destination-hex pathfinding: computing a legal path (terrain costs,
/// MP, stacking) is BattleTech movement-rule logic, which this app leaves to
/// the MegaMek server rather than reimplementing (see CLAUDE.md "Nicht-
/// Ziele").
class UnitActionPanel extends StatelessWidget {
  const UnitActionPanel({
    super.key,
    required this.unit,
    required this.phase,
    required this.pendingSteps,
    required this.onStep,
    required this.onClearSteps,
    required this.onConfirmMove,
    this.target,
    this.selectedWeaponIds = const {},
    this.onToggleWeapon,
    this.onConfirmAttack,
    required this.onDeselect,
  });

  final Unit unit;
  final String phase;
  final List<String> pendingSteps;
  final void Function(MoveStep step) onStep;
  final VoidCallback onClearSteps;
  final VoidCallback onConfirmMove;
  final Unit? target;
  final Set<int> selectedWeaponIds;
  final void Function(int equipmentId)? onToggleWeapon;
  final VoidCallback? onConfirmAttack;
  final VoidCallback onDeselect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    unit.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDeselect,
                ),
              ],
            ),
            Text(
              'Armor ${unit.armor}/${unit.totalArmor} · Internal ${unit.internal}/${unit.totalInternal}',
            ),
            const SizedBox(height: 8),
            Flexible(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (phase == 'MOVEMENT') {
      return _MoveBuilder(
        pendingSteps: pendingSteps,
        onStep: onStep,
        onClear: onClearSteps,
        onConfirm: onConfirmMove,
      );
    }
    if (phase == 'FIRING') {
      return _AttackBuilder(
        unit: unit,
        target: target,
        selectedWeaponIds: selectedWeaponIds,
        onToggleWeapon: onToggleWeapon,
        onConfirm: onConfirmAttack,
      );
    }
    return Text(
      'Nothing to do with this unit in the ${phase.toLowerCase()} phase.',
    );
  }
}

class _MoveBuilder extends StatelessWidget {
  const _MoveBuilder({
    required this.pendingSteps,
    required this.onStep,
    required this.onClear,
    required this.onConfirm,
  });

  final List<String> pendingSteps;
  final void Function(MoveStep step) onStep;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MoveStep.values
              .map(
                (step) => ElevatedButton(
                  onPressed: () => onStep(step),
                  child: Text(step.label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          pendingSteps.isEmpty ? 'No steps queued' : pendingSteps.join(' -> '),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: pendingSteps.isEmpty ? null : onClear,
                child: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: pendingSteps.isEmpty ? null : onConfirm,
                child: const Text('Confirm move'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttackBuilder extends StatelessWidget {
  const _AttackBuilder({
    required this.unit,
    required this.target,
    required this.selectedWeaponIds,
    required this.onToggleWeapon,
    required this.onConfirm,
  });

  final Unit unit;
  final Unit? target;
  final Set<int> selectedWeaponIds;
  final void Function(int equipmentId)? onToggleWeapon;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    if (unit.weapons.isEmpty) {
      return const Text('This unit has no weapons.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          target == null
              ? 'Tap an enemy unit to target'
              : 'Target: ${target!.displayName}',
        ),
        const SizedBox(height: 4),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: unit.weapons
                .map(
                  (weapon) => CheckboxListTile(
                    dense: true,
                    value: selectedWeaponIds.contains(weapon.equipmentId),
                    onChanged: onToggleWeapon == null
                        ? null
                        : (_) => onToggleWeapon!(weapon.equipmentId),
                    title: Text(weapon.name),
                  ),
                )
                .toList(),
          ),
        ),
        FilledButton(
          onPressed: (target != null && selectedWeaponIds.isNotEmpty)
              ? onConfirm
              : null,
          child: const Text('Fire'),
        ),
      ],
    );
  }
}
