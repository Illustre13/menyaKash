import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/accounts/accounts_service.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/providers/provider_selection_service.dart';
import 'package:i_momo/sms/isolate_parsing.dart';
import 'package:i_momo/sms/sms_ingest_service.dart';

/// Spec #11: only messages belonging to enabled providers may be
/// scanned and processed. The historical scan's provider snapshot is
/// the enforcement point — an unselected provider must be absent from
/// it entirely, so its senders never become scan candidates and it can
/// never be a resolution target.
void main() {
  late AppDatabase db;
  late ProviderSelectionService selection;

  Future<int> providerId(String code) async =>
      (await (db.select(db.financialProviders)..where((tbl) => tbl.code.equals(code)))
              .getSingle())
          .id;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    selection = ProviderSelectionService(db, AccountsService(db));
  });

  tearDown(() => db.close());

  test('no providers selected -> empty snapshot, nothing would be scanned', () async {
    expect(await snapshotSelectedProviders(db), isEmpty);
  });

  test('only selected providers appear in the scan snapshot', () async {
    await selection.selectProviders([await providerId('mtn_momo_rw')]);

    final snapshot = await snapshotSelectedProviders(db);
    expect(snapshot.map((p) => p.providerCode), ['mtn_momo_rw']);
    expect(
      snapshot.single.senderPatterns,
      contains('M-Money'),
      reason: 'the selected provider keeps its real sender patterns',
    );
  });

  test(
      'with only MTN selected, an eKash-bodied M-Money message resolves to '
      'no provider — shared-sender traffic for an unselected provider is skipped',
      () async {
    await selection.selectProviders([await providerId('mtn_momo_rw')]);
    final snapshot = await snapshotSelectedProviders(db);

    final results = parseChunk(ParseChunkInput(
      messages: [
        RawSmsSnapshot(
          sender: 'M-Money',
          body: '*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  '
              'has been completed at 2026-04-15 21:39:02. Fee was 20 RWF. '
              'Your new balance: 21931 RWF . Message: - ACSC. *EN#',
          receivedAt: DateTime(2026, 4, 15, 21, 39),
        ),
      ],
      providers: snapshot,
    ));

    expect(results.single.providerId, isNull,
        reason: 'eKash is not selected, so even though the sender is known, '
            'the message must not resolve to any provider');
  });

  test('deselecting a provider removes it from the next scan snapshot', () async {
    final mtn = await providerId('mtn_momo_rw');
    final equity = await providerId('equity_bank_rw');
    await selection.selectProviders([mtn, equity]);
    expect((await snapshotSelectedProviders(db)).length, 2);

    await selection.deselectProvider(equity);
    final snapshot = await snapshotSelectedProviders(db);
    expect(snapshot.map((p) => p.providerCode), ['mtn_momo_rw']);
  });
}
