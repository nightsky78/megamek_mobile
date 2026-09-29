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

  test('parses state.unit_catalog', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.unit_catalog',
      'schemaVersion': 1,
      'totalMatches': 3,
      'units': [
        {
          'ref': 'Atlas AS7-D',
          'chassis': 'Atlas',
          'model': 'AS7-D',
          'unitType': 'Mek',
          'tons': 100,
          'bv': 1897,
          'year': 3025,
          'techBase': 'Inner Sphere',
          'clan': false,
        },
      ],
    });
    expect(message, isA<UnitCatalogBridgeMessage>());
    final catalog = message as UnitCatalogBridgeMessage;
    expect(catalog.totalMatches, 3);
    expect(catalog.units, hasLength(1));
    expect(catalog.units.single.ref, 'Atlas AS7-D');
  });

  test(
    'unknown type falls back to UnknownBridgeMessage instead of throwing',
    () {
      final message = BridgeMessage.fromJson({'type': 'future.thing'});
      expect(message, isA<UnknownBridgeMessage>());
      expect((message as UnknownBridgeMessage).type, 'future.thing');
    },
  );
}
