import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/data/database.dart';
import 'package:i_momo/providers/provider_detector_factory.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('unambiguous sender resolves to its one provider at full confidence', () async {
    final detector = buildProviderDetector(db);
    final result = await detector.detect(sender: 'EQUITYBANK', body: 'irrelevant body');
    expect(result, isNotNull);
    expect(result!.provider.code, 'equity_bank_rw');
    expect(result.confidence, 1.0);
  });

  test('unknown sender resolves to null', () async {
    final detector = buildProviderDetector(db);
    final result = await detector.detect(sender: 'RANDOM-PROMO', body: 'win a prize');
    expect(result, isNull);
  });

  test('ambiguous M-Money sender resolves to eKash when body mentions eKash', () async {
    final detector = buildProviderDetector(db);
    final result = await detector.detect(
      sender: 'M-Money',
      body: '*162*TxId:13559072472*S*Your payment of 500 RWF to eKash with token  has been '
          'completed at 2024-04-15 21:39:02. Fee was 20 RWF. Your new balance: 21931 RWF .',
    );
    expect(result, isNotNull);
    expect(result!.provider.code, 'ekash_rw');
    expect(result.confidence, 0.9);
  });

  test('ambiguous M-Money sender resolves to MTN MoMo when body has no eKash mention', () async {
    final detector = buildProviderDetector(db);
    final result = await detector.detect(
      sender: 'M-Money',
      body: '*165*S*5000 RWF transferred to Hadidja Nyinawumuntu (250788765551) from '
          '15568442 at 2024-04-15 19:54:02 . Fee was: 100 RWF. New balance: 27551 RWF.',
    );
    expect(result, isNotNull);
    expect(result!.provider.code, 'mtn_momo_rw');
    expect(result.confidence, 0.9);
  });
}
