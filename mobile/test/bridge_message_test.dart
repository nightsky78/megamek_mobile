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

  test('parses state.report', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.report',
      'schemaVersion': 1,
      'round': 2,
      'phase': 'FIRING_REPORT',
      'text': 'Atlas hits Wolverine',
    });
    final entry = (message as ReportBridgeMessage).entry;
    expect(entry.round, 2);
    expect(entry.phase, 'FIRING_REPORT');
    expect(entry.text, 'Atlas hits Wolverine');
  });

  test('parses state.deploy_options', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.deploy_options',
      'schemaVersion': 1,
      'entityId': 3,
      'hexes': [
        {'x': 0, 'y': 1},
        {'x': 0, 'y': 2},
      ],
    });
    final options = (message as DeployOptionsBridgeMessage).options;
    expect(options.entityId, 3);
    expect(options.hexes, {(0, 1), (0, 2)});
  });

  test('parses state.move_options with MP costs', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.move_options',
      'schemaVersion': 1,
      'entityId': 3,
      'mode': 'RUN',
      'walkMp': 4,
      'runMp': 6,
      'jumpMp': 0,
      'hexes': [
        {'x': 4, 'y': 5, 'mp': 2},
      ],
    });
    final options = (message as MoveOptionsBridgeMessage).options;
    expect(options.runMp, 6);
    expect(options.hexes[(4, 5)], 2);
  });

  test('parses state.move_preview', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.move_preview',
      'schemaVersion': 1,
      'entityId': 3,
      'mode': 'WALK',
      'legal': true,
      'mpUsed': 3,
      'facing': 1,
      'path': [
        {'x': 1, 'y': 1},
        {'x': 2, 'y': 1},
      ],
      'message': null,
    });
    final preview = (message as MovePreviewBridgeMessage).preview;
    expect(preview.legal, isTrue);
    expect(preview.path, [(1, 1), (2, 1)]);
    expect(preview.message, isNull);
  });

  test('parses state.attack_options including impossible options', () {
    final message = BridgeMessage.fromJson({
      'type': 'state.attack_options',
      'schemaVersion': 1,
      'entityId': 3,
      'targetId': 9,
      'range': 4,
      'physical': false,
      'options': [
        {
          'key': '5',
          'name': 'Medium Laser',
          'toHit': 7,
          'probability': 58,
          'description': 'base 4',
          'damage': 5,
          'heat': 3,
          'possible': true,
        },
        {'key': '6', 'name': 'AC/20', 'toHit': null, 'possible': false},
      ],
    });
    final options = (message as AttackOptionsBridgeMessage).options;
    expect(options.options, hasLength(2));
    expect(options.options.first.probability, 58);
    expect(options.options.last.toHit, isNull);
    expect(options.options.last.possible, isFalse);
  });
}
