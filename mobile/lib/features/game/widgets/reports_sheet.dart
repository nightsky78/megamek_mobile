import 'package:flutter/material.dart';

import '../../../core/models/turn_models.dart';

/// Combat log: the game report the server produced, newest round first.
class ReportsSheet extends StatelessWidget {
  const ReportsSheet({super.key, required this.reports});

  final List<ReportEntry> reports;

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<ReportEntry>>{};
    for (final r in reports) {
      rounds.putIfAbsent(r.round, () => []).add(r);
    }
    final ordered = rounds.keys.toList()..sort((a, b) => b.compareTo(a));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) {
        if (reports.isEmpty) {
          return const Center(child: Text('Nothing has happened yet.'));
        }
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            for (final round in ordered) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  round == 0 ? 'Setup' : 'Round $round',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
              for (final entry in rounds[round]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.text,
                    style: const TextStyle(fontSize: 13, height: 1.3),
                  ),
                ),
              const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }
}
