import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/bridge_message.dart';

/// Owns the single WebSocket connection to the bridge (see
/// docs/decisions.md #8). One instance per app session; reconnecting means
/// creating a new instance (see bridge/README.md "Known limitations" - there
/// is no session resumption, a fresh connection just gets a fresh snapshot).
class BridgeClient {
  BridgeClient._(this._channel) {
    _subscription = _channel.stream.listen(
      (raw) => _messages.add(
        BridgeMessage.fromJson(
          jsonDecode(raw as String) as Map<String, dynamic>,
        ),
      ),
      onError: (Object error, StackTrace stackTrace) =>
          _messages.addError(error, stackTrace),
      onDone: () {
        if (!_messages.isClosed) {
          _messages.close();
        }
      },
    );
  }

  static Future<BridgeClient> connect(String host, int port) async {
    final uri = Uri.parse('ws://$host:$port/ws');
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    return BridgeClient._(channel);
  }

  final WebSocketChannel _channel;
  late final StreamSubscription<void> _subscription;
  final StreamController<BridgeMessage> _messages =
      StreamController<BridgeMessage>.broadcast();

  Stream<BridgeMessage> get messages => _messages.stream;

  void send(Map<String, dynamic> action) {
    _channel.sink.add(jsonEncode(action));
  }

  Future<void> close() async {
    await _subscription.cancel();
    try {
      await _channel.sink.close();
    } catch (_) {
      // Already closed by the peer; nothing left to do.
    }
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
