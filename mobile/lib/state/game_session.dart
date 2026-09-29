import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/actions.dart';
import '../core/models/bridge_message.dart';
import '../core/models/game_state_snapshot.dart';
import '../core/models/turn_models.dart';
import '../core/models/unit_summary.dart';
import '../core/net/bridge_client.dart';

sealed class SessionStatus {
  const SessionStatus();
}

class Disconnected extends SessionStatus {
  const Disconnected();
}

class Connecting extends SessionStatus {
  const Connecting();
}

class Connected extends SessionStatus {
  const Connected();
}

/// The socket dropped mid-session; the last snapshot stays on screen while the
/// app retries with backoff.
class Reconnecting extends SessionStatus {
  const Reconnecting(this.attempt);
  final int attempt;
}

class ConnectionError extends SessionStatus {
  const ConnectionError(this.message);
  final String message;
}

class GameSessionState {
  const GameSessionState({
    this.status = const Disconnected(),
    this.snapshot,
    this.chatLog = const [],
    this.reports = const [],
    this.catalogResults = const [],
    this.catalogTotalMatches = 0,
    this.deployOptions,
    this.moveOptions,
    this.movePreview,
    this.attackOptions,
    this.notice,
    this.noticeSeq = 0,
  });

  final SessionStatus status;
  final GameStateSnapshot? snapshot;
  final List<String> chatLog;
  final List<ReportEntry> reports;
  final List<UnitSummary> catalogResults;
  final int catalogTotalMatches;
  final DeployOptions? deployOptions;
  final MoveOptions? moveOptions;
  final MovePreview? movePreview;
  final AttackOptions? attackOptions;

  /// Latest error the bridge reported for an action; [noticeSeq] changes on
  /// every new one so the UI can show each as a snackbar exactly once.
  final String? notice;
  final int noticeSeq;

  bool get isLive => status is Connected || status is Reconnecting;

  GameSessionState copyWith({
    SessionStatus? status,
    GameStateSnapshot? snapshot,
    List<String>? chatLog,
    List<ReportEntry>? reports,
    List<UnitSummary>? catalogResults,
    int? catalogTotalMatches,
    DeployOptions? deployOptions,
    MoveOptions? moveOptions,
    MovePreview? movePreview,
    AttackOptions? attackOptions,
    bool clearDeployOptions = false,
    bool clearMoveOptions = false,
    bool clearMovePreview = false,
    bool clearAttackOptions = false,
    String? notice,
  }) => GameSessionState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    chatLog: chatLog ?? this.chatLog,
    reports: reports ?? this.reports,
    catalogResults: catalogResults ?? this.catalogResults,
    catalogTotalMatches: catalogTotalMatches ?? this.catalogTotalMatches,
    deployOptions: clearDeployOptions
        ? null
        : (deployOptions ?? this.deployOptions),
    moveOptions: clearMoveOptions ? null : (moveOptions ?? this.moveOptions),
    movePreview: clearMovePreview ? null : (movePreview ?? this.movePreview),
    attackOptions: clearAttackOptions
        ? null
        : (attackOptions ?? this.attackOptions),
    notice: notice ?? this.notice,
    noticeSeq: notice == null ? noticeSeq : noticeSeq + 1,
  );
}

/// Owns the bridge WebSocket connection and turns its messages into app
/// state. If the socket drops mid-session the last snapshot stays visible
/// while the notifier reconnects with backoff; the bridge sends a fresh
/// snapshot (and replays the game report) on every new connection.
class GameSessionNotifier extends Notifier<GameSessionState> {
  static const _pingInterval = Duration(seconds: 15);
  static const _maxBackoff = Duration(seconds: 10);

  BridgeClient? _client;
  StreamSubscription<BridgeMessage>? _subscription;
  Timer? _pingTimer;
  Timer? _retryTimer;
  String? _host;
  int? _port;
  bool _wantConnected = false;
  int _attempt = 0;

  @override
  GameSessionState build() {
    ref.onDispose(() {
      _wantConnected = false;
      _pingTimer?.cancel();
      _retryTimer?.cancel();
      _subscription?.cancel();
      _client?.close();
    });
    return const GameSessionState();
  }

  Future<void> connect(String host, int port) async {
    _host = host;
    _port = port;
    _wantConnected = true;
    _attempt = 0;
    state = state.copyWith(status: const Connecting());
    final error = await _open();
    if (error != null) {
      _wantConnected = false;
      state = state.copyWith(status: ConnectionError(error));
    }
  }

  /// Opens a fresh socket; returns an error text on failure.
  Future<String?> _open() async {
    try {
      final old = _client;
      final oldSubscription = _subscription;
      _client = null;
      _subscription = null;
      await oldSubscription?.cancel();
      unawaited(old?.close());

      final client = await BridgeClient.connect(_host!, _port!);
      _client = client;
      _subscription = client.messages.listen(
        _onMessage,
        onError: (Object error, StackTrace stackTrace) => _onDropped(),
        onDone: _onDropped,
      );
      _attempt = 0;
      _retryTimer?.cancel();
      // The bridge replays the report log on connect, so start empty.
      state = state.copyWith(status: const Connected(), reports: const []);
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(
        _pingInterval,
        (_) => _client?.send(Actions.ping()),
      );
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  void _onDropped() {
    if (!_wantConnected) {
      return;
    }
    _pingTimer?.cancel();
    _client = null;
    if (state.snapshot == null) {
      _wantConnected = false;
      state = state.copyWith(
        status: const ConnectionError('Connection to the bridge was lost'),
      );
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _attempt++;
    state = state.copyWith(status: Reconnecting(_attempt));
    final seconds = (1 << (_attempt - 1).clamp(0, 4)).clamp(
      1,
      _maxBackoff.inSeconds,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), () async {
      if (!_wantConnected) {
        return;
      }
      final error = await _open();
      if (error != null && _wantConnected) {
        _scheduleRetry();
      }
    });
  }

  /// Called when the app returns to the foreground: a phone that slept usually
  /// holds a dead socket that nothing has noticed yet, so start a new one.
  Future<void> resume() async {
    if (!_wantConnected || state.snapshot == null) {
      return;
    }
    final error = await _open();
    if (error != null && _wantConnected) {
      _scheduleRetry();
    }
  }

  /// Immediate retry (the "Retry now" button on the reconnect banner).
  Future<void> retryNow() => resume();

  void _onMessage(BridgeMessage event) {
    switch (event) {
      case SnapshotMessage(:final snapshot):
        final phaseChanged = state.snapshot?.phase != snapshot.phase;
        state = state.copyWith(
          status: const Connected(),
          snapshot: snapshot,
          // Options are only valid for the state they were computed in.
          clearDeployOptions: phaseChanged,
          clearMoveOptions: phaseChanged,
          clearMovePreview: phaseChanged,
          clearAttackOptions: phaseChanged,
        );
      case ChatBridgeMessage(:final text):
        state = state.copyWith(chatLog: [...state.chatLog, text]);
      case ConnectionStatusBridgeMessage(:final status, :final detail):
        if (status == 'error') {
          state = state.copyWith(
            status: ConnectionError(detail ?? 'Unknown bridge error'),
          );
        }
      case ErrorBridgeMessage(:final message):
        state = state.copyWith(
          chatLog: [...state.chatLog, '[bridge error] $message'],
          notice: message,
        );
      case UnitCatalogBridgeMessage(:final units, :final totalMatches):
        state = state.copyWith(
          catalogResults: units,
          catalogTotalMatches: totalMatches,
        );
      case ReportBridgeMessage(:final entry):
        state = state.copyWith(reports: [...state.reports, entry]);
      case DeployOptionsBridgeMessage(:final options):
        state = state.copyWith(deployOptions: options);
      case MoveOptionsBridgeMessage(:final options):
        state = state.copyWith(moveOptions: options);
      case MovePreviewBridgeMessage(:final preview):
        state = state.copyWith(movePreview: preview);
      case AttackOptionsBridgeMessage(:final options):
        state = state.copyWith(attackOptions: options);
      case UnknownBridgeMessage():
        break;
    }
  }

  void _send(Map<String, dynamic> action) => _client?.send(action);

  // --- turn loop -----------------------------------------------------------

  void requestDeployOptions(int entityId) =>
      _send(Actions.deployOptions(entityId));

  void sendDeploy({
    required int entityId,
    required int x,
    required int y,
    required int facing,
  }) {
    _send(Actions.deploy(entityId: entityId, x: x, y: y, facing: facing));
    state = state.copyWith(clearDeployOptions: true);
  }

  void requestMoveOptions(int entityId, String mode) =>
      _send(Actions.moveOptions(entityId: entityId, mode: mode));

  void requestMovePreview({
    required int entityId,
    required String mode,
    int? x,
    int? y,
    int? facing,
  }) => _send(
    Actions.movePreview(
      entityId: entityId,
      mode: mode,
      x: x,
      y: y,
      facing: facing,
    ),
  );

  void sendMoveTo({
    required int entityId,
    required String mode,
    int? x,
    int? y,
    int? facing,
  }) {
    _send(
      Actions.moveTo(
        entityId: entityId,
        mode: mode,
        x: x,
        y: y,
        facing: facing,
      ),
    );
    state = state.copyWith(clearMoveOptions: true, clearMovePreview: true);
  }

  void requestAttackOptions({
    required int entityId,
    required int targetId,
    bool physical = false,
  }) => _send(
    Actions.attackOptions(
      entityId: entityId,
      targetId: targetId,
      physical: physical,
    ),
  );

  void sendAttack({
    required int entityId,
    required int targetId,
    required List<int> weaponIds,
  }) {
    _send(
      Actions.attack(
        entityId: entityId,
        targetId: targetId,
        weaponIds: weaponIds,
      ),
    );
    state = state.copyWith(clearAttackOptions: true);
  }

  /// Empty attack = "this unit does not fire".
  void sendSkipAttack(int entityId) {
    _send(Actions.attack(entityId: entityId, targetId: 0, weaponIds: const []));
    state = state.copyWith(clearAttackOptions: true);
  }

  void sendPhysical({required int entityId, int? targetId, String? kind}) {
    _send(Actions.physical(entityId: entityId, targetId: targetId, kind: kind));
    state = state.copyWith(clearAttackOptions: true);
  }

  void clearTurnOptions() => state = state.copyWith(
    clearDeployOptions: true,
    clearMoveOptions: true,
    clearMovePreview: true,
    clearAttackOptions: true,
  );

  void sendEndPhase({bool done = true}) => _send(Actions.endPhase(done: done));

  void sendChat(String text) => _send(Actions.chat(text));

  // --- lobby ---------------------------------------------------------------

  void sendAddUnit(String unitRef) => _send(Actions.addUnit(unitRef: unitRef));

  void sendAddBot(String botName, {String? difficulty}) =>
      _send(Actions.addBot(botName: botName, difficulty: difficulty));

  void sendAddBotUnit({required String botName, required String unitRef}) =>
      _send(Actions.addBotUnit(botName: botName, unitRef: unitRef));

  void sendRemoveUnit(int entityId) => _send(Actions.removeUnit(entityId));

  void sendSetPilot({required int entityId, int? gunnery, int? piloting}) =>
      _send(
        Actions.setPilot(
          entityId: entityId,
          gunnery: gunnery,
          piloting: piloting,
        ),
      );

  void sendSetTeam({required int team, String? botName}) =>
      _send(Actions.setTeam(team: team, botName: botName));

  void sendSelectBoard(List<String> boardNames) =>
      _send(Actions.selectBoard(boardNames: boardNames));

  void sendStartGame() => _send(Actions.startGame());

  void sendNewGame() => _send(Actions.newGame());

  void searchUnitCatalog({
    String? text,
    String? unitType,
    bool? clanOnly,
    double? minTons,
    double? maxTons,
    int? limit,
    int? minYear,
    int? maxYear,
    int? minBv,
    int? maxBv,
    String? techBase,
  }) => _send(
    Actions.searchUnitCatalog(
      text: text,
      unitType: unitType,
      clanOnly: clanOnly,
      minTons: minTons,
      maxTons: maxTons,
      limit: limit,
      minYear: minYear,
      maxYear: maxYear,
      minBv: minBv,
      maxBv: maxBv,
      techBase: techBase,
    ),
  );

  Future<void> disconnect() async {
    _wantConnected = false;
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _client?.close();
    _client = null;
    _subscription = null;
    state = const GameSessionState();
  }
}

final gameSessionProvider =
    NotifierProvider<GameSessionNotifier, GameSessionState>(
      GameSessionNotifier.new,
    );

/// Currently selected unit in the map/lobby UI (detail sheet, move/attack
/// builder). `null` means nothing selected.
class SelectedUnitNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? unitId) => state = unitId;
}

final selectedUnitIdProvider = NotifierProvider<SelectedUnitNotifier, int?>(
  SelectedUnitNotifier.new,
);

/// Which lobby setup sub-screen is showing (roster/bots/map). Purely
/// client-side UI navigation, not game state - `LobbyScreen` branches on this
/// internally, while `HomeShell` keeps choosing the Lobby screen from
/// `phase == 'LOUNGE'` alone (see docs/decisions.md #6).
enum LobbySetupStep { overview, roster, bots, map }

class LobbySetupNotifier extends Notifier<LobbySetupStep> {
  @override
  LobbySetupStep build() => LobbySetupStep.overview;

  void select(LobbySetupStep step) => state = step;
}

final lobbySetupStepProvider =
    NotifierProvider<LobbySetupNotifier, LobbySetupStep>(
      LobbySetupNotifier.new,
    );
