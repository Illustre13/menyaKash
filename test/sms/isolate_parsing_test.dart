import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart' show hashSmsMessage;
import 'package:i_momo/sms/isolate_parsing.dart';

/// parseChunk is a plain top-level function — testable by calling it
/// directly (no compute()/real isolate needed) against a fixture
/// provider snapshot, exactly the same as it will run in production.
void main() {
  const mtnProvider = ProviderSnapshot(
    providerId: 1,
    providerCode: 'mtn_momo_rw',
    senderPatterns: ['M-Money'],
    disambiguator: DisambiguatorRule.notContainsEkash,
  );
  const ekashProvider = ProviderSnapshot(
    providerId: 2,
    providerCode: 'ekash_rw',
    senderPatterns: ['M-Money'],
    disambiguator: DisambiguatorRule.containsEkash,
  );
  const equityProvider = ProviderSnapshot(
    providerId: 3,
    providerCode: 'equity_bank_rw',
    senderPatterns: ['EQUITYBANK'],
  );

  test('a real MTN message on the shared M-Money sender resolves to MTN, not eKash', () {
    final input = ParseChunkInput(
      messages: [
        RawSmsSnapshot(
          sender: 'M-Money',
          body: 'You have received 5000 RWF from Jean Uwimana (250788123456) on your mobile '
              'money account at 2026-07-08 14:32:10. Message from sender: . Your new '
              'balance:12500 RWF. Financial Transaction Id: 987654321.',
          receivedAt: DateTime(2026, 7, 8, 14, 32, 10),
        ),
      ],
      providers: [mtnProvider, ekashProvider],
    );

    final results = parseChunk(input);
    expect(results, hasLength(1));
    expect(results.single.providerId, mtnProvider.providerId);
    expect(results.single.wasParsed, isTrue);
    expect(results.single.parsed!.amount, 5000);
  });

  test('a real eKash message on the same shared sender resolves to eKash, not MTN', () {
    final input = ParseChunkInput(
      messages: [
        RawSmsSnapshot(
          sender: 'M-Money',
          body: '*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  has '
              'been completed at 2026-04-15 21:39:02. Fee was 20 RWF. Your new balance: '
              '21931 RWF . Message: - ACSC. *EN#',
          receivedAt: DateTime(2026, 4, 15, 21, 39, 2),
        ),
      ],
      providers: [mtnProvider, ekashProvider],
    );

    final results = parseChunk(input);
    expect(results.single.providerId, ekashProvider.providerId);
    expect(results.single.wasParsed, isTrue);
  });

  test('an unknown sender resolves to no provider at all', () {
    final input = ParseChunkInput(
      messages: [
        RawSmsSnapshot(sender: 'SPAM', body: 'Buy now!', receivedAt: DateTime(2026, 1, 1)),
      ],
      providers: [mtnProvider, ekashProvider, equityProvider],
    );

    final results = parseChunk(input);
    expect(results.single.providerId, isNull);
    expect(results.single.wasParsed, isFalse);
  });

  test('a known sender with a body no parser understands is unrecognized, not thrown', () {
    final input = ParseChunkInput(
      messages: [
        RawSmsSnapshot(
          sender: 'EQUITYBANK',
          body: 'a shape no parser understands yet',
          receivedAt: DateTime(2026, 1, 1),
        ),
      ],
      providers: [equityProvider],
    );

    final results = parseChunk(input);
    expect(results.single.providerId, equityProvider.providerId);
    expect(results.single.wasParsed, isFalse);
  });

  test('identical sender+body+receivedAt always produce the same hash (dedup key stability)', () {
    final message = RawSmsSnapshot(
      sender: 'M-Money',
      body: 'same body',
      receivedAt: DateTime(2026, 1, 1, 10, 0),
    );
    final input = ParseChunkInput(messages: [message, message], providers: [mtnProvider]);

    final results = parseChunk(input);
    expect(results[0].smsHash, results[1].smsHash);
  });

  test('parseChunk\'s hash formula matches hashSmsMessage exactly — critical, or the batch '
      'scan path would dedupe differently than the live listener path', () {
    const sender = 'M-Money';
    const body = 'some real message body';
    final receivedAt = DateTime(2026, 3, 4, 5, 6, 7);

    final input = ParseChunkInput(
      messages: [RawSmsSnapshot(sender: sender, body: body, receivedAt: receivedAt)],
      providers: [mtnProvider],
    );
    final result = parseChunk(input).single;

    expect(
      result.smsHash,
      hashSmsMessage(sender: sender, body: body, receivedAt: receivedAt),
    );
  });
}
