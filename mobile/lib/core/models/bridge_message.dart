import 'game_state_snapshot.dart';
import 'turn_models.dart';
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
      'state.report' => ReportBridgeMessage(ReportEntry.fromJson(json)),
      'state.deploy_options' => DeployOptionsBridgeMessage(
        DeployOptions.fromJson(json),
      ),
      'state.move_options' => MoveOptionsBridgeMessage(
        MoveOptions.fromJson(json),
      ),
      'state.move_preview' => MovePreviewBridgeMessage(
        MovePreview.fromJson(json),
      ),
      'state.attack_options' => AttackOptionsBridgeMessage(
        AttackOptions.fromJson(json),
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

class ReportBridgeMessage extends BridgeMessage {
  const ReportBridgeMessage(this.entry);
  final ReportEntry entry;
}

class DeployOptionsBridgeMessage extends BridgeMessage {
  const DeployOptionsBridgeMessage(this.options);
  final DeployOptions options;
}

class MoveOptionsBridgeMessage extends BridgeMessage {
  const MoveOptionsBridgeMessage(this.options);
  final MoveOptions options;
}

class MovePreviewBridgeMessage extends BridgeMessage {
  const MovePreviewBridgeMessage(this.preview);
  final MovePreview preview;
}

class AttackOptionsBridgeMessage extends BridgeMessage {
  const AttackOptionsBridgeMessage(this.options);
  final AttackOptions options;
}
