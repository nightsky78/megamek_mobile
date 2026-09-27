import 'package:flutter_test/flutter_test.dart';
import 'package:megamek_mobile/core/models/bridge_message.dart';

void main() {
  test('parses chat.message', () {
    final message = BridgeMessage.fromJson({
      'type': 'chat.message',
      'schemaVersion': 1,
      'text': 'Pilot1: good hunting',
    });
    expect(message, isA<ChatBridgeMessage>());
    expect((message as ChatBridgeMessage).text, 'Pilot1: good hunting');
  });

  test('parses connection.status', () {
    final message = BridgeMessage.fromJson({
      'type': 'connection.status',
      'schemaVersion': 1,
      'status': 'connected',
      'detail': null,
    });
    expect(message, isA<ConnectionStatusBridgeMessage>());
    expect((message as ConnectionStatusBridgeMessage).status, 'connected');
  });

  test('parses error', () {
    final message = BridgeMessage.fromJson({
      'type': 'error',
      'schemaVersion': 1,
      'message': 'boom',
    });
    expect(message, isA<ErrorBridgeMessage>());
    expect((message as ErrorBridgeMessage).message, 'boom');
  });

  test('unknown type falls back to UnknownBridgeMessage instead of throwing', () {
    final message = BridgeMessage.fromJson({'type': 'future.thing'});
    expect(message, isA<UnknownBridgeMessage>());
    expect((message as UnknownBridgeMessage).type, 'future.thing');
  });
}
