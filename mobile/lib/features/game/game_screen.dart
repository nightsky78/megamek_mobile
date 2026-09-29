import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/board.dart';
import '../../core/models/game_state_snapshot.dart';
import '../../core/models/turn_models.dart';
import '../../core/models/unit.dart';
import '../../state/game_session.dart';
import '../../theme/app_theme.dart';
import 'hex_geometry.dart';
import 'hex_map_painter.dart';
import 'widgets/chat_panel.dart';
import 'widgets/minimap.dart';
import 'widgets/phase_bar.dart';
import 'widgets/reports_sheet.dart';
import 'widgets/turn_panels.dart';
import 'widgets/unit_detail_sheet.dart';
import 'widgets/unit_list_sheet.dart';

/// Main battle screen: the hex map plus a context-sensitive panel that walks
/// the player through deploying, moving, firing and physical attacks for one
/// unit at a time. All rules (legal hexes, path costs, to-hit numbers) come
/// from the bridge; this widget only holds the half-finished choices.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  static const _hexSize = 28.0;
  static const _turnPhases = {'DEPLOYMENT', 'MOVEMENT', 'FIRING', 'PHYSICAL'};

  final _transform = TransformationController();
  Size _viewport = Size.zero;
  Board? _fittedBoard;

  String _mode = 'WALK';
  HexCoord? _dest;
  bool _turning = false;
  int? _facing;
  HexCoord? _deployHex;
  int _deployFacing = 0;
  int? _targetId;
  Set<String>? _selection;

  String? _requestKey;
  int _seenNotice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ sync

  void _resetLocal() {
    _dest = null;
    _turning = false;
    _facing = null;
    _deployHex = null;
    _targetId = null;
    _selection = null;
  }

  /// Keeps the selected unit, the bridge-side option requests and the local
  /// half-finished choices consistent with the latest session state.
  void _sync() {
    if (!mounted) {
      return;
    }
    final session = ref.read(gameSessionProvider);
    final snapshot = session.snapshot;
    if (snapshot == null) {
      return;
    }
    final notifier = ref.read(gameSessionProvider.notifier);
    var changed = false;

    if (session.noticeSeq != _seenNotice) {
      _seenNotice = session.noticeSeq;
      _requestKey = null;
      _resetLocal();
      changed = true;
    }

    final actionable = snapshot.myTurn && _turnPhases.contains(snapshot.phase);
    final selectedId = ref.read(selectedUnitIdProvider);
    var active = selectedId;
    if (actionable && snapshot.actableEntityIds.isNotEmpty) {
      if (selectedId == null ||
          !snapshot.actableEntityIds.contains(selectedId)) {
        active = snapshot.actableEntityIds.first;
        _selectUnit(active, snapshot);
        _resetLocal();
        _mode = 'WALK';
        changed = true;
      }
    }

    if (actionable &&
        active != null &&
        snapshot.actableEntityIds.contains(active)) {
      final key = '${snapshot.phase}:${snapshot.round}:$active:$_mode';
      if (key != _requestKey) {
        _requestKey = key;
        if (snapshot.phase == 'DEPLOYMENT') {
          notifier.requestDeployOptions(active);
        } else if (snapshot.phase == 'MOVEMENT') {
          notifier.requestMoveOptions(active, _mode);
        }
      }
    } else {
      _requestKey = null;
    }

    if (changed) {
      setState(() {});
    }
  }

  void _selectUnit(int? id, GameStateSnapshot snapshot) {
    ref.read(selectedUnitIdProvider.notifier).select(id);
    final unit = id == null ? null : snapshot.unitById(id);
    if (unit != null && unit.isDeployed) {
      _centerOn(HexGeometry(_hexSize).centerOf(unit.x, unit.y));
    }
  }

  // ----------------------------------------------------------------- viewport

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _setView(double scale, Offset canvasPoint) {
    final tx = _viewport.width / 2 - canvasPoint.dx * scale;
    final ty = _viewport.height / 2 - canvasPoint.dy * scale;
    _transform.value = Matrix4(
      scale,
      0,
      0,
      0, //
      0,
      scale,
      0,
      0, //
      0,
      0,
      1,
      0, //
      tx,
      ty,
      0,
      1,
    );
  }

  void _centerOn(Offset canvasPoint) {
    if (_viewport == Size.zero) {
      return;
    }
    _setView(max(_scale, 0.9), canvasPoint);
  }

  void _fit(Board board) {
    if (_viewport == Size.zero) {
      return;
    }
    final size = HexGeometry(_hexSize).canvasSizeFor(board.width, board.height);
    final scale = min(
      _viewport.width / size.width,
      _viewport.height / size.height,
    );
    _setView(scale.clamp(0.25, 2.0), size.center(Offset.zero));
  }

  void _initialView(Board board, GameStateSnapshot snapshot) {
    if (identical(_fittedBoard, board) || _viewport == Size.zero) {
      return;
    }
    _fittedBoard = board;
    final mine = snapshot.units.where(
      (u) =>
          u.ownerId == snapshot.localPlayerId && u.isDeployed && !u.destroyed,
    );
    if (mine.isNotEmpty) {
      _setView(0.9, HexGeometry(_hexSize).centerOf(mine.first.x, mine.first.y));
    } else {
      _fit(board);
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    ref.listen<GameSessionState>(gameSessionProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    });
    final session = ref.watch(gameSessionProvider);
    final snapshot = session.snapshot!;
    final board = snapshot.boards.isEmpty ? null : snapshot.boards.first;
    final selectedUnitId = ref.watch(selectedUnitIdProvider);
    final selectedUnit = selectedUnitId == null
        ? null
        : snapshot.unitById(selectedUnitId);
    final localPlayer = snapshot.localPlayer;

    if (board == null) {
      return const Scaffold(
        body: Center(child: Text('Waiting for the board...')),
      );
    }

    final geometry = HexGeometry(_hexSize);
    final canvasSize = geometry.canvasSizeFor(board.width, board.height);
    Color unitColor(Unit unit) => _colorForUnit(unit, snapshot.localPlayerId);

    final active = _activeUnit(snapshot, selectedUnit);
    final layout = _mapOverlays(session, snapshot, active);
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height * 1.15;

    return Scaffold(
      appBar: PhaseBar(
        snapshot: snapshot,
        isLocalPlayerDone: localPlayer?.done ?? false,
        onEndPhase: () => ref.read(gameSessionProvider.notifier).sendEndPhase(),
        onOpenUnits: () => _openUnitList(context, snapshot),
        onOpenChat: () => _openChat(context, session.chatLog),
        onOpenLog: () => _openLog(context),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _initialView(board, snapshot),
          );
          final panel = snapshot.phase == 'VICTORY'
              ? null
              : _buildPanel(session, snapshot, active, selectedUnit);
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: 0.2,
                  maxScale: 3,
                  boundaryMargin: const EdgeInsets.all(240),
                  child: GestureDetector(
                    onTapUp: (details) =>
                        _handleTap(details, board, snapshot, active),
                    child: CustomPaint(
                      size: canvasSize,
                      painter: HexMapPainter(
                        board: board,
                        units: snapshot.units,
                        geometry: geometry,
                        unitColor: unitColor,
                        selectedUnitId: selectedUnitId,
                        highlightedHexes: layout.highlight,
                        envelope: layout.envelope,
                        path: layout.path,
                        ghost: layout.ghost,
                        targetUnitId: _targetId,
                        actableIds: snapshot.myTurn
                            ? snapshot.actableEntityIds.toSet()
                            : const {},
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TurnBanner(snapshot: snapshot, active: active),
              ),
              Positioned(
                left: 8,
                top: 44,
                child: Column(
                  children: [
                    _mapButton(Icons.fit_screen, 'Fit map', () => _fit(board)),
                    if (selectedUnit != null && selectedUnit.isDeployed)
                      _mapButton(
                        Icons.my_location,
                        'Center on unit',
                        () => _centerOn(
                          geometry.centerOf(selectedUnit.x, selectedUnit.y),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                top: 44,
                child: Minimap(
                  board: board,
                  units: snapshot.units,
                  unitColor: unitColor,
                ),
              ),
              if (panel != null)
                landscape
                    ? Positioned(
                        right: 8,
                        top: 44 + 100,
                        bottom: 8,
                        width: min(340, constraints.maxWidth * 0.45),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SingleChildScrollView(
                            reverse: true,
                            child: panel,
                          ),
                        ),
                      )
                    : Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8 + media.padding.bottom,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.5,
                          ),
                          child: SingleChildScrollView(
                            reverse: true,
                            child: panel,
                          ),
                        ),
                      ),
              if (snapshot.phase == 'VICTORY')
                Positioned.fill(
                  child: _VictoryOverlay(
                    snapshot: snapshot,
                    onLog: () => _openLog(context),
                    onNewGame: () {
                      _resetLocal();
                      ref.read(selectedUnitIdProvider.notifier).select(null);
                      ref.read(gameSessionProvider.notifier).sendNewGame();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IconButton.filledTonal(
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }

  /// The unit the player is currently issuing orders to (only while it is
  /// the local player's turn and the unit may actually act).
  Unit? _activeUnit(GameStateSnapshot snapshot, Unit? selected) {
    if (selected == null ||
        !snapshot.myTurn ||
        !_turnPhases.contains(snapshot.phase) ||
        !snapshot.actableEntityIds.contains(selected.id)) {
      return null;
    }
    return selected;
  }

  _MapOverlays _mapOverlays(
    GameSessionState session,
    GameStateSnapshot snapshot,
    Unit? active,
  ) {
    if (active == null) {
      return const _MapOverlays();
    }
    final color = AppTheme.friendly;
    switch (snapshot.phase) {
      case 'DEPLOYMENT':
        final options = session.deployOptions;
        final hex = _deployHex;
        return _MapOverlays(
          highlight: options != null && options.entityId == active.id
              ? options.hexes
              : const {},
          ghost: hex == null
              ? null
              : UnitGhost(
                  x: hex.$1,
                  y: hex.$2,
                  facing: _deployFacing,
                  color: color,
                ),
        );
      case 'MOVEMENT':
        final options = session.moveOptions;
        final preview = _matchingPreview(session, active);
        final ghost = _dest != null
            ? UnitGhost(
                x: _dest!.$1,
                y: _dest!.$2,
                facing: _facing ?? preview?.facing ?? active.facing,
                color: color,
              )
            : _turning
            ? UnitGhost(
                x: active.x,
                y: active.y,
                facing: _facing ?? active.facing,
                color: color,
              )
            : null;
        return _MapOverlays(
          envelope:
              options != null &&
                  options.entityId == active.id &&
                  options.mode == _mode &&
                  _dest == null &&
                  !_turning
              ? options.hexes
              : const {},
          path: preview?.path ?? const [],
          ghost: ghost,
        );
      default:
        return const _MapOverlays();
    }
  }

  MovePreview? _matchingPreview(GameSessionState session, Unit active) {
    final p = session.movePreview;
    if (p == null || p.entityId != active.id || p.mode != _mode) {
      return null;
    }
    final dest = _dest;
    if (dest != null && (p.path.isEmpty || p.path.last != dest)) {
      return null;
    }
    return p;
  }

  Widget? _buildPanel(
    GameSessionState session,
    GameStateSnapshot snapshot,
    Unit? active,
    Unit? selected,
  ) {
    final notifier = ref.read(gameSessionProvider.notifier);
    if (active == null) {
      if (selected == null) {
        return null;
      }
      return _InfoPanel(
        unit: selected,
        mine: selected.ownerId == snapshot.localPlayerId,
        onDetails: () => _openDetails(selected),
        onClose: () => ref.read(selectedUnitIdProvider.notifier).select(null),
      );
    }
    void details() => _openDetails(active);

    switch (snapshot.phase) {
      case 'DEPLOYMENT':
        final options = session.deployOptions;
        return DeployPanel(
          unit: active,
          legalHexCount: options?.entityId == active.id
              ? options!.hexes.length
              : null,
          chosen: _deployHex,
          facing: _deployFacing,
          onRotate: (d) =>
              setState(() => _deployFacing = (_deployFacing + d) % 6),
          onDeploy: () {
            final hex = _deployHex!;
            notifier.sendDeploy(
              entityId: active.id,
              x: hex.$1,
              y: hex.$2,
              facing: _deployFacing,
            );
            setState(_resetLocal);
          },
          onDetails: details,
        );
      case 'MOVEMENT':
        final preview = _matchingPreview(session, active);
        final facing = _facing ?? preview?.facing ?? active.facing;
        return MovePanel(
          unit: active,
          mode: _mode,
          options: session.moveOptions?.entityId == active.id
              ? session.moveOptions
              : null,
          preview: preview,
          hasDestination: _dest != null,
          turning: _turning,
          facing: facing,
          onMode: (mode) {
            setState(() {
              _mode = mode;
              _dest = null;
              _turning = false;
              _facing = null;
            });
            _sync();
          },
          onRotate: (d) {
            final next = (facing + d + 6) % 6;
            setState(() => _facing = next);
            _requestPreview(active);
          },
          onMove: () {
            final dest = _dest;
            notifier.sendMoveTo(
              entityId: active.id,
              mode: _mode,
              x: dest?.$1,
              y: dest?.$2,
              facing: _facing ?? (dest == null ? facing : null),
            );
            setState(_resetLocal);
          },
          onStandStill: () {
            notifier.sendMoveTo(entityId: active.id, mode: 'WALK');
            setState(_resetLocal);
          },
          onStartTurn: () => setState(() {
            _turning = true;
            _facing = active.facing;
          }),
          onGetUp: () {
            notifier.sendMoveTo(
              entityId: active.id,
              mode: 'WALK',
              x: active.x,
              y: active.y,
            );
            setState(_resetLocal);
          },
          onCancel: () => setState(() {
            _dest = null;
            _turning = false;
            _facing = null;
          }),
          onDetails: details,
        );
      case 'FIRING':
      case 'PHYSICAL':
        final physical = snapshot.phase == 'PHYSICAL';
        final target = _targetId == null ? null : snapshot.unitById(_targetId!);
        final options = session.attackOptions;
        final matching =
            options != null &&
                options.entityId == active.id &&
                options.targetId == _targetId &&
                options.physical == physical
            ? options
            : null;
        final selection = _selection ?? _defaultSelection(matching, physical);
        return FirePanel(
          unit: active,
          target: target,
          options: matching,
          selected: selection,
          physical: physical,
          onClearTarget: () => setState(() {
            _targetId = null;
            _selection = null;
          }),
          onToggle: (key) => setState(() {
            if (physical) {
              _selection = {key};
              return;
            }
            final next = {...selection};
            if (!next.remove(key)) {
              next.add(key);
            }
            _selection = next;
          }),
          onFire: () {
            if (physical) {
              notifier.sendPhysical(
                entityId: active.id,
                targetId: _targetId,
                kind: selection.first,
              );
            } else {
              notifier.sendAttack(
                entityId: active.id,
                targetId: _targetId!,
                weaponIds: [for (final k in selection) int.parse(k)],
              );
            }
            setState(_resetLocal);
          },
          onSkip: () {
            if (physical) {
              notifier.sendPhysical(entityId: active.id);
            } else {
              notifier.sendSkipAttack(active.id);
            }
            setState(_resetLocal);
          },
          onDetails: details,
        );
      default:
        return null;
    }
  }

  Set<String> _defaultSelection(AttackOptions? options, bool physical) {
    if (options == null) {
      return const {};
    }
    final possible = [
      for (final o in options.options)
        if (o.possible) o,
    ];
    if (physical) {
      if (possible.isEmpty) {
        return const {};
      }
      possible.sort((a, b) => b.damage.compareTo(a.damage));
      return {possible.first.key};
    }
    return {for (final o in possible) o.key};
  }

  void _requestPreview(Unit active) {
    final dest = _dest;
    ref
        .read(gameSessionProvider.notifier)
        .requestMovePreview(
          entityId: active.id,
          mode: _mode,
          x: dest?.$1,
          y: dest?.$2,
          facing: _facing,
        );
  }

  // --------------------------------------------------------------- map taps

  void _handleTap(
    TapUpDetails details,
    Board board,
    GameStateSnapshot snapshot,
    Unit? active,
  ) {
    final hex = HexGeometry(
      _hexSize,
    ).hexAt(details.localPosition, board.width, board.height);
    if (hex == null) {
      return;
    }
    final session = ref.read(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final tapped = snapshot.units
        .where(
          (u) => u.isDeployed && u.x == hex.$1 && u.y == hex.$2 && !u.destroyed,
        )
        .firstOrNull;

    if (active != null) {
      switch (snapshot.phase) {
        case 'DEPLOYMENT':
          final legal = session.deployOptions?.hexes ?? const {};
          if (legal.contains(hex)) {
            setState(() {
              _deployHex = hex;
              if (_deployFacing == 0) {
                _deployFacing = _defaultDeployFacing(hex, board);
              }
            });
          }
          return;
        case 'MOVEMENT':
          if (hex == (active.x, active.y)) {
            if (active.prone) {
              return;
            }
            setState(() {
              _dest = null;
              _turning = true;
              _facing ??= active.facing;
            });
            _requestPreview(active);
            return;
          }
          final options = session.moveOptions;
          if (options != null && options.hexes.containsKey(hex)) {
            setState(() {
              _dest = hex;
              _turning = false;
              _facing = null;
            });
            _requestPreview(active);
            return;
          }
        case 'FIRING':
        case 'PHYSICAL':
          if (tapped != null && tapped.ownerId != snapshot.localPlayerId) {
            setState(() {
              _targetId = tapped.id;
              _selection = null;
            });
            notifier.requestAttackOptions(
              entityId: active.id,
              targetId: tapped.id,
              physical: snapshot.phase == 'PHYSICAL',
            );
            return;
          }
      }
    }

    if (tapped != null) {
      _selectUnit(tapped.id, snapshot);
      if (active == null || tapped.id != active.id) {
        setState(_resetLocal);
      }
    }
  }

  int _defaultDeployFacing(HexCoord hex, Board board) {
    final left = hex.$1 < board.width / 2;
    final top = hex.$2 < board.height / 2;
    if (top) {
      return left ? 2 : 4;
    }
    return left ? 1 : 5;
  }

  // ------------------------------------------------------------------ sheets

  void _openDetails(Unit unit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => UnitDetailSheet(unit: unit),
    );
  }

  void _openUnitList(BuildContext context, GameStateSnapshot snapshot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => UnitListSheet(
        units: snapshot.units,
        localPlayerId: snapshot.localPlayerId,
        onSelect: (unit) {
          _selectUnit(unit.id, snapshot);
          _openDetails(unit);
        },
      ),
    );
  }

  void _openLog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) =>
            ReportsSheet(reports: ref.watch(gameSessionProvider).reports),
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

  Color _colorForUnit(Unit unit, int? localPlayerId) {
    if (unit.destroyed) {
      return Colors.grey;
    }
    return unit.ownerId == localPlayerId ? AppTheme.friendly : AppTheme.hostile;
  }
}

class _MapOverlays {
  const _MapOverlays({
    this.highlight = const {},
    this.envelope = const {},
    this.path = const [],
    this.ghost,
  });

  final Set<HexCoord> highlight;
  final Map<HexCoord, int> envelope;
  final List<HexCoord> path;
  final UnitGhost? ghost;
}

/// One-line status strip: whose turn it is and what is expected of the user.
class _TurnBanner extends ConsumerWidget {
  const _TurnBanner({required this.snapshot, required this.active});

  final GameStateSnapshot snapshot;
  final Unit? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (text, color) = _content();
    return IgnorePointer(
      child: Container(
        height: 34,
        alignment: Alignment.center,
        color: color.withValues(alpha: 0.92),
        child: Text(
          text,
          key: const Key('turn-banner'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  (String, Color) _content() {
    if (snapshot.phase == 'VICTORY') {
      return ('Game over', Colors.blueGrey);
    }
    if (snapshot.isReportPhase) {
      return (
        'Round ${snapshot.round} report - read the log, then Continue',
        Colors.blueGrey.shade700,
      );
    }
    if (snapshot.myTurn) {
      final verb = switch (snapshot.phase) {
        'DEPLOYMENT' => 'deploy',
        'MOVEMENT' => 'move',
        'FIRING' => 'fire',
        'PHYSICAL' => 'physical attacks',
        _ => 'act',
      };
      final left = snapshot.actableEntityIds.length;
      return (
        'Your turn: $verb${left > 0 ? ' ($left unit${left == 1 ? '' : 's'} left)' : ''}',
        Colors.green.shade800,
      );
    }
    final who = snapshot.players
        .where((p) => p.id == snapshot.turnPlayerId)
        .firstOrNull;
    return (
      who == null
          ? 'Waiting for other players...'
          : 'Waiting for ${who.name}...',
      Colors.grey.shade800,
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.unit,
    required this.mine,
    required this.onDetails,
    required this.onClose,
  });

  final Unit unit;
  final bool mine;
  final VoidCallback onDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      unit: unit,
      title: mine ? 'Your unit' : 'Enemy',
      onDetails: onDetails,
      trailing: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close),
        onPressed: onClose,
      ),
      child: Text(
        'Pilot ${unit.pilotName} (${unit.gunnery}/${unit.piloting}) · '
        '${unit.tons.toStringAsFixed(0)} t · BV ${unit.bv}',
        style: const TextStyle(fontSize: 12, color: Colors.white60),
      ),
    );
  }
}

class _VictoryOverlay extends StatelessWidget {
  const _VictoryOverlay({
    required this.snapshot,
    required this.onLog,
    required this.onNewGame,
  });

  final GameStateSnapshot snapshot;
  final VoidCallback onLog;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final result = snapshot.result;
    final won = result?.localWon ?? false;
    final draw = result == null || result.winnerPlayerId < 0;
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  draw
                      ? Icons.handshake
                      : won
                      ? Icons.emoji_events
                      : Icons.dangerous,
                  size: 48,
                  color: draw
                      ? Colors.white70
                      : won
                      ? Colors.amber
                      : Colors.redAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  draw
                      ? 'Draw'
                      : won
                      ? 'Victory!'
                      : 'Defeat',
                  key: const Key('victory-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (result != null && result.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(result.summary, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: onLog,
                      child: const Text('Combat log'),
                    ),
                    FilledButton(
                      key: const Key('new-game-button'),
                      onPressed: onNewGame,
                      child: const Text('New game'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
