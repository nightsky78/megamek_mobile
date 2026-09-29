import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/actions.dart';
import '../core/models/bridge_message.dart';
import '../core/models/game_state_snapshot.dart';
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

class ConnectionError extends SessionStatus {
  const ConnectionError(this.message);
  final String message;
}

class GameSessionState {
  const GameSessionState({
    this.status = const Disconnected(),
    this.snapshot,
    this.chatLog = const [],
    this.catalogResults = const [],
    this.catalogTotalMatches = 0,
  });

  final SessionStatus status;
  final GameStateSnapshot? snapshot;
  final List<String> chatLog;
  final List<UnitSummary> catalogResults;
  final int catalogTotalMatches;

  GameSessionState copyWith({
    SessionStatus? status,
    GameStateSnapshot? snapshot,
    List<String>? chatLog,
    List<UnitSummary>? catalogResults,
    int? catalogTotalMatches,
  }) => GameSessionState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    chatLog: chatLog ?? this.chatLog,
    catalogResults: catalogResults ?? this.catalogResults,
    catalogTotalMatches: catalogTotalMatches ?? this.catalogTotalMatches,
  );
}

/// Owns the bridge WebSocket connection and turns its messages into app
/// state. One session per connect; disconnecting drops the client entirely
/// (see bridge/README.md "Known limitations": no reconnection/session
/// resumption in the MVP).
class GameSessionNotifier extends Notifier<GameSessionState> {
  BridgeClient? _client;
  StreamSubscription<BridgeMessage>? _subscription;

  @override
  GameSessionState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _client?.close();
    });
    return const GameSessionState();
  }

  Future<void> connect(String host, int port) async {
    state = state.copyWith(status: const Connecting());
    try {
      final client = await BridgeClient.connect(host, port);
      _client = client;
      _subscription = client.messages.listen(
        _onMessage,
        onError: (Object error, StackTrace stackTrace) {
          state = state.copyWith(status: ConnectionError(error.toString()));
        },
      );
      state = state.copyWith(status: const Connected());
    } catch (error) {
      state = state.copyWith(status: ConnectionError(error.toString()));
    }
  }

  void _onMessage(BridgeMessage event) {
    switch (event) {
      case SnapshotMessage(:final snapshot):
        state = state.copyWith(status: const Connected(), snapshot: snapshot);
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
        );
      case UnitCatalogBridgeMessage(:final units, :final totalMatches):
        state = state.copyWith(
          catalogResults: units,
          catalogTotalMatches: totalMatches,
        );
      case UnknownBridgeMessage():
        break;
    }
  }

  void sendMove(int entityId, List<String> steps) =>
      _client?.send(Actions.move(entityId: entityId, steps: steps));

  void sendAttack({
    required int entityId,
    required int targetId,
    required List<int> weaponIds,
  }) => _client?.send(
    Actions.attack(
      entityId: entityId,
      targetId: targetId,
      weaponIds: weaponIds,
    ),
  );

  void sendEndPhase({bool done = true}) =>
      _client?.send(Actions.endPhase(done: done));

  void sendChat(String text) => _client?.send(Actions.chat(text));

  void sendAddUnit(String unitRef) =>
      _client?.send(Actions.addUnit(unitRef: unitRef));

  void sendAddBot(String botName) =>
      _client?.send(Actions.addBot(botName: botName));

  void sendAddBotUnit({required String botName, required String unitRef}) =>
      _client?.send(Actions.addBotUnit(botName: botName, unitRef: unitRef));

  void sendSelectBoard(List<String> boardNames) =>
      _client?.send(Actions.selectBoard(boardNames: boardNames));

  void sendStartGame() => _client?.send(Actions.startGame());

  void searchUnitCatalog({
    String? text,
    String? unitType,
    bool? clanOnly,
    double? minTons,
    double? maxTons,
    int? limit,
  }) => _client?.send(
    Actions.searchUnitCatalog(
      text: text,
      unitType: unitType,
      clanOnly: clanOnly,
      minTons: minTons,
      maxTons: maxTons,
      limit: limit,
    ),
  );

  Future<void> disconnect() async {
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
