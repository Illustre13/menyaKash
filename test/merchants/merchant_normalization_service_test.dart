import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/merchants/merchant_normalization_service.dart';

void main() {
  late AppDatabase db;
  late MerchantNormalizationService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = MerchantNormalizationService(db);
  });

  tearDown(() => db.close());

  group('extractMerchantName — against real confirmed counterparty strings', () {
    test('strips a trailing 6-digit account code', () {
      expect(
        service.extractMerchantName('HOPITAL LA CROIX DU SUD Ltd 100126'),
        'HOPITAL LA CROIX DU SUD Ltd',
      );
    });

    test('strips a trailing code separated by a dash', () {
      expect(
        service.extractMerchantName('Future Dynamic Innovations FDI Ltd - 20231'),
        'Future Dynamic Innovations FDI Ltd',
      );
    });

    test('strips a trailing 5-digit code from a personal name used as a till', () {
      expect(service.extractMerchantName('Pacifique 08077'), 'Pacifique');
    });

    test('leaves a plain personal name with no code untouched', () {
      expect(service.extractMerchantName('Jean Uwimana'), 'Jean Uwimana');
    });
  });

  group('normalize', () {
    test('collapses casing/punctuation/whitespace differences to the same key', () {
      final a = service.normalize('Family Bakery Ltd');
      final b = service.normalize('FAMILY BAKERY LTD.');
      final c = service.normalize('family   bakery ltd');
      expect(a, b);
      expect(b, c);
    });
  });

  group('resolveMerchant', () {
    test('creates a new Merchant on first sight', () async {
      final merchant = await service.resolveMerchant('HOPITAL LA CROIX DU SUD Ltd 100126');
      expect(merchant, isNotNull);
      expect(merchant!.name, 'HOPITAL LA CROIX DU SUD Ltd');
    });

    test('resolves near-duplicate spellings to the same Merchant row', () async {
      final first = await service.resolveMerchant('Family Bakery Ltd 55123');
      final second = await service.resolveMerchant('FAMILY BAKERY LTD. 55123');
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.id, second!.id);
    });

    test('returns null for a null or empty counterparty', () async {
      expect(await service.resolveMerchant(null), isNull);
      expect(await service.resolveMerchant(''), isNull);
      expect(await service.resolveMerchant('   '), isNull);
    });

    test(
        'rejects an over-128-char mis-extraction instead of crashing or '
        'minting a garbage merchant — the InvalidDataException guard', () async {
      // Shaped like the real crash input: a parser bug leaking token +
      // external-transaction payload into the counterparty. Must never
      // reach the Merchants insert (which would throw on the 128-char
      // column cap) and must not create a truncated fake merchant either.
      const leaked = 'MTN Cash Power with token '
          '1111-2222-3333-4444-5555-6666-7777-8888-9999-0000 '
          'External Transaction Id 987654321012345678901234567890 '
          'padding padding padding padding padding padding';
      expect(leaked.length, greaterThan(128), reason: 'test premise');

      expect(await service.resolveMerchant(leaked), isNull);
      expect(await db.select(db.merchants).get(), isEmpty,
          reason: 'no merchant row of any kind may be created from garbage');
    });
  });
}
