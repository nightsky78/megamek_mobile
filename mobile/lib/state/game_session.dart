import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/actions.dart';
import '../core/models/bridge_message.dart';
import '../core/models/game_state_snapshot.dart';
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
  });

  final SessionStatus status;
  final GameStateSnapshot? snapshot;
  final List<String> chatLog;

  GameSessionState copyWith({
    SessionStatus? status,
    GameStateSnapshot? snapshot,
    List<String>? chatLog,
  }) =>
      GameSessionState(
        status: status ?? this.status,
        snapshot: snapshot ?? this.snapshot,
        chatLog: chatLog ?? this.chatLog,
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
          state = state.copyWith(status: ConnectionError(detail ?? 'Unknown bridge error'));
        }
      case ErrorBridgeMessage(:final message):
        state = state.copyWith(chatLog: [...state.chatLog, '[bridge error] $message']);
      case UnknownBridgeMessage():
        break;
    }
  }

  void sendMove(int entityId, List<String> steps) =>
      _client?.send(Actions.move(entityId: entityId, steps: steps));

  void sendAttack({required int entityId, required int targetId, required List<int> weaponIds}) =>
      _client?.send(Actions.attack(entityId: entityId, targetId: targetId, weaponIds: weaponIds));

  void sendEndPhase({bool done = true}) => _client?.send(Actions.endPhase(done: done));

  void sendChat(String text) => _client?.send(Actions.chat(text));

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _client?.close();
    _client = null;
    _subscription = null;
    state = const GameSessionState();
  }
}

final gameSessionProvider = NotifierProvider<GameSessionNotifier, GameSessionState>(GameSessionNotifier.new);

/// Currently selected unit in the map/lobby UI (detail sheet, move/attack
/// builder). `null` means nothing selected.
class SelectedUnitNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? unitId) => state = unitId;
}

final selectedUnitIdProvider = NotifierProvider<SelectedUnitNotifier, int?>(SelectedUnitNotifier.new);
