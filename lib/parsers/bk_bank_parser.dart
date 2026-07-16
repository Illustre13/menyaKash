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
/// The newer English shape's own destination line varies by
/// counterparty network — confirmed real: `TRANSFER - MTN mobile
/// money`/`TRANSFER - MTN Mobile Money` (mobile wallet), `TRANSFER -
/// Bank of Kigali` (an internal BK-to-BK transfer to a different BK
/// account), and `TRANSFER - I&M BANK` (a different bank entirely) all
/// share the same `Credited account:`/`Amount:`/`Event #:`/`Available
/// Balance:` field layout — every one of them is a real debit from
/// *this* BK account, regardless of which network the money lands on,
/// so all three intros are treated identically here. Only the intro
/// literal changes; a genuinely different field layout would need its
/// own branch.
class BkBankParser extends MomoParser {
  @override
  String get providerCode => 'bk_bank_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)';

  static final _transferIntro = RegExp(
    r'TRANSFER\s*-\s*(?:MTN\s+[Mm]obile\s+[Mm]oney|Bank\s+of\s+Kigali|I&M\s+BANK)',
    caseSensitive: false,
  );
  static final _depositIntro = RegExp(r'has\s+deposited\s+RWF', caseSensitive: false);

  // Older Kinyarwanda shape: "Umubare:RWF 100000.0  Igikorwa #: REF"
  static final _kinyaAmountField =
      RegExp('Umubare\\s*:\\s*RWF\\s*$_amountGroup', caseSensitive: false);
  static final _kinyaRefField = RegExp(r'Igikorwa\s*#:\s*(\w+)', caseSensitive: false);
  static final _kinyaDateField = RegExp(
    r'Itariki:\s*(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );

  // Newer English shape: "Amount: RWF 100,000 ... Event #: REF ...
  // Date: 7/14/26, 10:18 AM ... Available Balance: RWF 2,485,630"
  static final _englishAmountField =
      RegExp('Amount:\\s*RWF\\s*$_amountGroup', caseSensitive: false);
  static final _englishRefField = RegExp(r'Event\s*#:\s*(\w+)', caseSensitive: false);
  static final _englishDateField = RegExp(
    r'Date:\s*(\d{1,2})/(\d{1,2})/(\d{2})\s*,?\s*(\d{1,2}):(\d{2})\s*(AM|PM)?',
    caseSensitive: false,
  );
  static final _availableBalanceField =
      RegExp('Available\\s+Balance:\\s*RWF\\s*$_amountGroup', caseSensitive: false);

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

    if (_transferIntro.hasMatch(normalized)) {
      final amount = _toDouble(_kinyaAmountField.firstMatch(normalized)?.group(1)) ??
          _toDouble(_englishAmountField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;

      final txRef = _kinyaRefField.firstMatch(normalized)?.group(1) ??
          _englishRefField.firstMatch(normalized)?.group(1);
      final timestamp = _extractDate(_kinyaDateField, normalized) ??
          _extractEnglishDate(normalized) ??
          receivedAt ??
          DateTime.now();

      return ParsedTransaction(
        type: TransactionType.bankTransfer,
        amount: amount,
        txRef: txRef,
        balanceAfter: _toDouble(_availableBalanceField.firstMatch(normalized)?.group(1)),
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
        balanceAfter: _toDouble(_availableBalanceField.firstMatch(normalized)?.group(1)),
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

  /// The English shape's date is US-style month/day/2-digit-year with a
  /// 12-hour clock ("7/14/26, 10:18 AM"), a different shape entirely
  /// from the Kinyarwanda shape's ISO-ish "Itariki:" field — kept as its
  /// own extractor rather than folding into [_extractDate].
  static DateTime? _extractEnglishDate(String body) {
    final match = _englishDateField.firstMatch(body);
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    final year = 2000 + int.parse(match.group(3)!);
    var hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final meridiem = match.group(6)?.toUpperCase();
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    try {
      return DateTime(year, month, day, hour, minute);
    } on ArgumentError {
      return null;
    }
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
