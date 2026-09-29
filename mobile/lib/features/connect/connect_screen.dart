import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/game_session.dart';

/// Portrait-first entry screen (Phase 3: "Portrait für Lobby/Menüs"): enter
/// the bridge's host/port and connect. Host/port, not a MegaMek server
/// address - the bridge is the only thing this app ever talks to directly
/// (see CLAUDE.md architecture diagram).
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _hostController = TextEditingController(text: 'localhost');
  final _portController = TextEditingController(text: '8080');

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    final connecting = session.status is Connecting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.satellite_alt,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'MegaMek Mobile',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect to your bridge',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Bridge host',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !connecting,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Bridge port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !connecting,
                  ),
                  const SizedBox(height: 24),
                  if (session.status case ConnectionError(:final message))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: connecting ? null : _connect,
                    child: connecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _connect() {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null) {
      return;
    }
    ref.read(gameSessionProvider.notifier).connect(host, port);
  }
}
