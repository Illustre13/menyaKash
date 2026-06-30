import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses Equity Bank (Rwanda) notification SMS.
///
/// Built directly from real message text — see
/// `docs/SMS_PATTERN_LIBRARY.md` (Equity section) and the redacted
/// fixtures in `test/fixtures/equity_bank/`. Two confirmed real `sent`
/// shapes exist (to an MTN-linked phone number with an `MTN Ref.`, vs.
/// to a masked account with only a plain `Ref.`) — both map to
/// `TransactionType.bankTransfer`, not `sent`, since every confirmed
/// Equity transaction observed is a bank-side movement, matching how
/// this app already models BK Bank transfers.
///
/// No confirmed real Equity message reports a running balance — unlike
/// every MTN/Airtel shape. `ParsedTransaction.balanceAfter` is always
/// null for this parser; that's expected, not a parsing gap.
class EquityBankParser extends MomoParser {
  @override
  String get providerCode => 'equity_bank_rw';

  static const _amountGroup = r'([\d,]+\.\d{2})\s*RWF';

  static final _sentIntro =
      RegExp(r'RWF\s+(?:was|has\s+been)\s+successfully\s+sent\s+to', caseSensitive: false);
  static final _receivedIntro = RegExp(r'you\s+have\s+received', caseSensitive: false);

  static final _amountField = RegExp(_amountGroup, caseSensitive: false);

  /// The cross-provider correlation key for transfer matching (Phase 3)
  /// — confirmed real: `MTN Ref. 541077019015` appears specifically on
  /// transfers routed to an MTN MoMo number, distinct from the generic
  /// `Ref.` every Equity message also carries.
  static final _mtnRefField = RegExp(r'MTN\s+Ref\.\s*(\w+)', caseSensitive: false);
  static final _refField = RegExp(r'\bRef\.\s*(\w+)', caseSensitive: false);

  static final _sentToField = RegExp(
    r'sent\s+to\s+(.+?)\s+(?:on\s+\d|MTN\s+Ref\.|Ref\.)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _receivedFromField = RegExp(
    r'from\s+(.+?)\s+to\s+your\s+Equity\s+account',
    caseSensitive: false,
    dotAll: true,
  );

  /// `on 17/04/26 at 19:24:13 CAT` or `on 20 Nov 2026 at 14:12 CAT` —
  /// both confirmed real date formats (numeric-slash and
  /// day-month-name), used interchangeably by Equity across different
  /// message shapes for the same field.
  static final _slashDate = RegExp(
    r'on\s+(\d{1,2})/(\d{1,2})/(\d{2})\s+at\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    caseSensitive: false,
  );
  static final _namedMonthDate = RegExp(
    r'on\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+at\s+(\d{1,2}):(\d{2})',
    caseSensitive: false,
  );
  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    final amount = _toDouble(_amountField.firstMatch(normalized)?.group(1));
    if (amount == null) return null;

    final timestamp = _extractTimestamp(normalized) ?? receivedAt ?? DateTime.now();
    final txRef = (_mtnRefField.firstMatch(normalized) ?? _refField.firstMatch(normalized))
        ?.group(1);

    if (_sentIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.bankTransfer,
        amount: amount,
        counterparty: _sentToField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        timestamp: timestamp,
      );
    }

    if (_receivedIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.received,
        amount: amount,
        counterparty: _receivedFromField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        timestamp: timestamp,
      );
    }

    return null;
  }

  static DateTime? _extractTimestamp(String body) {
    final slash = _slashDate.firstMatch(body);
    if (slash != null) {
      final day = int.parse(slash.group(1)!);
      final month = int.parse(slash.group(2)!);
      final year = 2000 + int.parse(slash.group(3)!);
      final hour = int.parse(slash.group(4)!);
      final minute = int.parse(slash.group(5)!);
      final second = slash.group(6) != null ? int.parse(slash.group(6)!) : 0;
      try {
        return DateTime(year, month, day, hour, minute, second);
      } on ArgumentError {
        return null;
      }
    }

    final named = _namedMonthDate.firstMatch(body);
    if (named != null) {
      final day = int.parse(named.group(1)!);
      final month = _months[named.group(2)!.toLowerCase()];
      if (month == null) return null;
      final year = int.parse(named.group(3)!);
      final hour = int.parse(named.group(4)!);
      final minute = int.parse(named.group(5)!);
      try {
        return DateTime(year, month, day, hour, minute);
      } on ArgumentError {
        return null;
      }
    }

    return null;
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
