import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses eKash notification SMS. eKash shares MTN Rwanda's `M-Money`
/// sender shortcode but is a distinct provider (`ekash_rw`) —
/// disambiguated from real `mtn_momo_rw` traffic by
/// `ProviderDetector`/`provider_detector_factory.dart` before a message
/// ever reaches this parser (see `docs/AUDIT_PHASE_0.md` §3.2 and
/// `docs/ARCHITECTURE.md` §8a).
///
/// The only confirmed real eKash message shape (`docs/SMS_PATTERN_LIBRARY.md`)
/// is a payment: `*162*TxId:ID*S*Your payment of AMOUNT RWF to eKash with
/// token  has been completed at TIMESTAMP. Fee was FEE RWF. Your new
/// balance: BAL RWF...` — identical in structure to MTN's own merchant
/// payment shape, just always to the literal merchant "eKash". No real
/// eKash `received`/`withdrawal`/`deposit` message was found in the
/// source export; this parser intentionally doesn't guess at those.
class EkashParser extends MomoParser {
  @override
  String get providerCode => 'ekash_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)\s*RWF';

  static final _paymentIntro = RegExp(r'your\s+payment\s+of', caseSensitive: false);
  static final _amountField = RegExp(_amountGroup, caseSensitive: false);
  static final _feeField =
      RegExp(r'fee\s+(?:was|paid)[:\s]*' '$_amountGroup', caseSensitive: false);
  static final _balanceField =
      RegExp(r'new\s+balance\s*[:\s]+' '$_amountGroup', caseSensitive: false);
  static final _txRefField = RegExp(r'TxId\s*[:.]?\s*(\w+)', caseSensitive: false);
  static final _toField =
      RegExp(r'RWF\s+to\s+(.+?)\s+has\s+been\s+completed', caseSensitive: false, dotAll: true);
  static final _embeddedDate = RegExp(
    r'(?:at|on)\s+(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    caseSensitive: false,
  );

  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    if (!_paymentIntro.hasMatch(normalized)) return null;

    final amount = _toDouble(_amountField.firstMatch(normalized)?.group(1));
    if (amount == null) return null;

    final timestamp = _extractTimestamp(normalized) ?? receivedAt ?? DateTime.now();

    return ParsedTransaction(
      type: TransactionType.payment,
      amount: amount,
      counterparty: _toField.firstMatch(normalized)?.group(1)?.trim(),
      fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
      txRef: _txRefField.firstMatch(normalized)?.group(1),
      balanceAfter: _toDouble(_balanceField.firstMatch(normalized)?.group(1)),
      timestamp: timestamp,
    );
  }

  static DateTime? _extractTimestamp(String body) {
    final match = _embeddedDate.firstMatch(body);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = match.group(6) != null ? int.parse(match.group(6)!) : 0;
    try {
      return DateTime(year, month, day, hour, minute, second);
    } on ArgumentError {
      return null;
    }
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
