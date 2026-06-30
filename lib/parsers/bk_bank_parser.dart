import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses Bank of Kigali (BK) notification SMS.
///
/// Built directly from real message text — see
/// `docs/SMS_PATTERN_LIBRARY.md` (BK section) and the redacted fixtures
/// in `test/fixtures/bk_bank/`. **Confirmed real: BK changed its own
/// TRANSFER message format between an older Kinyarwanda version
/// (`Konti ihabwa amafr:` / `Igikorwa #:`) and a newer English version
/// (`Credited account:` / `Event #:`)** — both appear in the same real
/// export at different dates, so both are modeled as separate regex
/// alternatives here, not assumed to be one shape with cosmetic
/// differences.
///
/// `TRANSFER - Bank of ...` and `TRANSFER - I&M BANK ...` variants
/// (transfers to other banks, not MTN mobile money) were observed in
/// the source export but are NOT covered here — flagged as a known gap
/// rather than silently guessed at; such messages fall through to the
/// unparsed-message review queue.
class BkBankParser extends MomoParser {
  @override
  String get providerCode => 'bk_bank_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)';

  static final _transferToMomoIntro =
      RegExp(r'TRANSFER\s*-\s*MTN\s+mobile\s+money', caseSensitive: false);
  static final _depositIntro = RegExp(r'has\s+deposited\s+RWF', caseSensitive: false);

  // Older Kinyarwanda shape: "Umubare:RWF 100000.0  Igikorwa #: REF"
  static final _kinyaAmountField =
      RegExp('Umubare\\s*:\\s*RWF\\s*$_amountGroup', caseSensitive: false);
  static final _kinyaRefField = RegExp(r'Igikorwa\s*#:\s*(\w+)', caseSensitive: false);
  static final _kinyaDateField = RegExp(
    r'Itariki:\s*(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );

  // Newer English shape: "Amount: RWF 100,000 ... Event #: REF"
  static final _englishAmountField =
      RegExp('Amount:\\s*RWF\\s*$_amountGroup', caseSensitive: false);
  static final _englishRefField = RegExp(r'Event\s*#:\s*(\w+)', caseSensitive: false);

  // Deposit shape: "has deposited RWF AMOUNT to (... ). ... Date: ..."
  static final _depositAmountField =
      RegExp('deposited\\s+RWF\\s*$_amountGroup', caseSensitive: false);
  static final _depositRefField = RegExp(r'Deposit\s+Ref#:\s*(\w+)', caseSensitive: false);
  static final _depositDateField = RegExp(
    r'Date:\s*(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );

  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();

    if (_transferToMomoIntro.hasMatch(normalized)) {
      final amount = _toDouble(_kinyaAmountField.firstMatch(normalized)?.group(1)) ??
          _toDouble(_englishAmountField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;

      final txRef = _kinyaRefField.firstMatch(normalized)?.group(1) ??
          _englishRefField.firstMatch(normalized)?.group(1);
      final timestamp =
          _extractDate(_kinyaDateField, normalized) ?? receivedAt ?? DateTime.now();

      return ParsedTransaction(
        type: TransactionType.bankTransfer,
        amount: amount,
        txRef: txRef,
        timestamp: timestamp,
      );
    }

    if (_depositIntro.hasMatch(normalized)) {
      final amount = _toDouble(_depositAmountField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;

      final timestamp =
          _extractDate(_depositDateField, normalized) ?? receivedAt ?? DateTime.now();

      return ParsedTransaction(
        type: TransactionType.deposit,
        amount: amount,
        txRef: _depositRefField.firstMatch(normalized)?.group(1),
        timestamp: timestamp,
      );
    }

    return null;
  }

  static DateTime? _extractDate(RegExp pattern, String body) {
    final match = pattern.firstMatch(body);
    if (match == null) return null;
    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
      );
    } on ArgumentError {
      return null;
    }
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
