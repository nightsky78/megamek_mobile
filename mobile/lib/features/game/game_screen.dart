import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/board.dart';
import '../../core/models/game_state_snapshot.dart';
import '../../core/models/player.dart';
import '../../core/models/unit.dart';
import '../../state/game_session.dart';
import '../../theme/app_theme.dart';
import 'hex_geometry.dart';
import 'hex_map_painter.dart';
import 'widgets/chat_panel.dart';
import 'widgets/minimap.dart';
import 'widgets/phase_bar.dart';
import 'widgets/unit_action_panel.dart';
import 'widgets/unit_list_sheet.dart';

/// Main battle screen: hex map (landscape-primary, Phase 3), phase bar,
/// minimap overlay, and a bottom action panel for the selected unit.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  static const _hexSize = 28.0;

  List<String> _pendingSteps = [];
  Set<int> _selectedWeaponIds = {};
  int? _targetUnitId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    final snapshot = session.snapshot!;
    final board = snapshot.boards.isEmpty ? null : snapshot.boards.first;
    final selectedUnitId = ref.watch(selectedUnitIdProvider);
    final selectedUnit = _findUnit(snapshot.units, selectedUnitId);
    final localPlayer = _findPlayer(snapshot, snapshot.localPlayerId);

    if (board == null) {
      return const Scaffold(
        body: Center(child: Text('Waiting for the board...')),
      );
    }

    final geometry = HexGeometry(_hexSize);
    final canvasSize = geometry.canvasSizeFor(board.width, board.height);
    Color unitColor(Unit unit) => _colorForUnit(unit, snapshot.localPlayerId);

    return Scaffold(
      appBar: PhaseBar(
        snapshot: snapshot,
        isLocalPlayerDone: localPlayer?.done ?? false,
        onEndPhase: () => ref.read(gameSessionProvider.notifier).sendEndPhase(),
        onOpenUnits: () =>
            _openUnitList(context, snapshot.units, snapshot.localPlayerId),
        onOpenChat: () => _openChat(context, session.chatLog),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 4,
              minScale: 0.3,
              child: GestureDetector(
                onTapUp: (details) =>
                    _handleTap(details, board, snapshot.units, geometry),
                child: CustomPaint(
                  size: canvasSize,
                  painter: HexMapPainter(
                    board: board,
                    units: snapshot.units,
                    geometry: geometry,
                    unitColor: unitColor,
                    selectedUnitId: selectedUnitId,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Minimap(
              board: board,
              units: snapshot.units,
              unitColor: unitColor,
            ),
          ),
          if (selectedUnit != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: UnitActionPanel(
                unit: selectedUnit,
                phase: snapshot.phase,
                pendingSteps: _pendingSteps,
                onStep: (step) => setState(
                  () => _pendingSteps = [..._pendingSteps, step.wireName],
                ),
                onClearSteps: () => setState(() => _pendingSteps = []),
                onConfirmMove: () => _confirmMove(selectedUnit),
                target: _findUnit(snapshot.units, _targetUnitId),
                selectedWeaponIds: _selectedWeaponIds,
                onToggleWeapon: (id) => setState(() {
                  _selectedWeaponIds = {..._selectedWeaponIds};
                  if (!_selectedWeaponIds.remove(id)) {
                    _selectedWeaponIds.add(id);
                  }
                }),
                onConfirmAttack: () => _confirmAttack(selectedUnit),
                onDeselect: () => _deselect(),
              ),
            ),
        ],
      ),
    );
  }

  void _handleTap(
    TapUpDetails details,
    Board board,
    List<Unit> units,
    HexGeometry geometry,
  ) {
    final hex = geometry.hexAt(
      details.localPosition,
      board.width,
      board.height,
    );
    if (hex == null) {
      return;
    }
    final tappedUnit = units.where(
      (u) => u.isDeployed && u.x == hex.$1 && u.y == hex.$2 && !u.destroyed,
    );
    if (tappedUnit.isEmpty) {
      return;
    }
    final unit = tappedUnit.first;
    final localPlayerId = ref.read(gameSessionProvider).snapshot?.localPlayerId;

    if (unit.ownerId == localPlayerId) {
      ref.read(selectedUnitIdProvider.notifier).select(unit.id);
      setState(() {
        _pendingSteps = [];
        _selectedWeaponIds = {};
        _targetUnitId = null;
      });
    } else if (ref.read(selectedUnitIdProvider) != null) {
      setState(() => _targetUnitId = unit.id);
    }
  }

  void _confirmMove(Unit unit) {
    ref.read(gameSessionProvider.notifier).sendMove(unit.id, _pendingSteps);
    setState(() => _pendingSteps = []);
  }

  void _confirmAttack(Unit unit) {
    if (_targetUnitId == null || _selectedWeaponIds.isEmpty) {
      return;
    }
    ref
        .read(gameSessionProvider.notifier)
        .sendAttack(
          entityId: unit.id,
          targetId: _targetUnitId!,
          weaponIds: _selectedWeaponIds.toList(),
        );
    setState(() {
      _selectedWeaponIds = {};
      _targetUnitId = null;
    });
    _deselect();
  }

  void _deselect() {
    ref.read(selectedUnitIdProvider.notifier).select(null);
    setState(() {
      _pendingSteps = [];
      _selectedWeaponIds = {};
      _targetUnitId = null;
    });
  }

  void _openUnitList(
    BuildContext context,
    List<Unit> units,
    int? localPlayerId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => UnitListSheet(
        units: units,
        localPlayerId: localPlayerId,
        onSelect: (unit) =>
            ref.read(selectedUnitIdProvider.notifier).select(unit.id),
      ),
    );
  }

  void _openChat(BuildContext context, List<String> chatLog) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ChatPanel(
          chatLog: chatLog,
          onSend: (text) =>
              ref.read(gameSessionProvider.notifier).sendChat(text),
        ),
      ),
    );
  }

  Unit? _findUnit(List<Unit> units, int? id) {
    if (id == null) {
      return null;
    }
    final matches = units.where((u) => u.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Player? _findPlayer(GameStateSnapshot snapshot, int? id) {
    if (id == null) {
      return null;
    }
    final matches = snapshot.players.where((p) => p.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Color _colorForUnit(Unit unit, int? localPlayerId) {
    if (unit.destroyed) {
      return Colors.grey;
    }
    return unit.ownerId == localPlayerId ? AppTheme.friendly : AppTheme.hostile;
  }
}
