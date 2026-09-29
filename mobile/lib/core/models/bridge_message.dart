import 'game_state_snapshot.dart';
import 'unit_summary.dart';

/// Discriminator for every message the bridge pushes on `/ws` (see
/// bridge/README.md "Server → Client messages").
sealed class BridgeMessage {
  const BridgeMessage();

  static BridgeMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'state.snapshot' => SnapshotMessage(GameStateSnapshot.fromJson(json)),
      'chat.message' => ChatBridgeMessage(json['text'] as String),
      'connection.status' => ConnectionStatusBridgeMessage(
        status: json['status'] as String,
        detail: json['detail'] as String?,
      ),
      'error' => ErrorBridgeMessage(json['message'] as String),
      'state.unit_catalog' => UnitCatalogBridgeMessage(
        units: (json['units'] as List<dynamic>)
            .map((u) => UnitSummary.fromJson(u as Map<String, dynamic>))
            .toList(),
        totalMatches: json['totalMatches'] as int,
      ),
      _ => UnknownBridgeMessage(type ?? 'null'),
    };
  }
}

class SnapshotMessage extends BridgeMessage {
  const SnapshotMessage(this.snapshot);
  final GameStateSnapshot snapshot;
}

class ChatBridgeMessage extends BridgeMessage {
  const ChatBridgeMessage(this.text);
  final String text;
}

class ConnectionStatusBridgeMessage extends BridgeMessage {
  const ConnectionStatusBridgeMessage({required this.status, this.detail});
  final String status;
  final String? detail;
}

class ErrorBridgeMessage extends BridgeMessage {
  const ErrorBridgeMessage(this.message);
  final String message;
}

class UnknownBridgeMessage extends BridgeMessage {
  const UnknownBridgeMessage(this.type);
  final String type;
}

class UnitCatalogBridgeMessage extends BridgeMessage {
  const UnitCatalogBridgeMessage({
    required this.units,
    required this.totalMatches,
  });
  final List<UnitSummary> units;
  final int totalMatches;
}
