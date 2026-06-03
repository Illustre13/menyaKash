import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';

import '../data/database.dart';

/// Surfaces SMS from a known MoMo sender that no parser could match.
/// This is the "initialize new message format" loop in practice: when
/// MTN changes wording or a new template shows up, it lands here instead
/// of being silently dropped, so the regexes in the relevant parser can
/// be extended to cover it.
class ReviewUnparsedScreen extends StatelessWidget {
  const ReviewUnparsedScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unrecognized messages')),
      body: StreamBuilder<List<UnparsedMessage>>(
        stream: (db.select(db.unparsedMessages)
              ..where((tbl) => tbl.resolved.equals(false))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.receivedAt)]))
            .watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing to review — every MoMo message so far matched '
                  'a known format.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.sender),
                subtitle: Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: 'Mark as reviewed (not a transaction)',
                  onPressed: () {
                    (db.update(db.unparsedMessages)
                          ..where((tbl) => tbl.id.equals(item.id)))
                        .write(const UnparsedMessagesCompanion(
                      resolved: Value(true),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
