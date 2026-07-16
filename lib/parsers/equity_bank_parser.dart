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
/// A third confirmed real shape — "Dear NAME, you have been
/// debited/credited with RWF AMOUNT Charge C ref REF from BRANCH On:
/// DD-Mon-YY HH:MM:SS balance BAL" — is a genuine bank-statement-style
/// notification that DOES report a running balance (`balanceAfter`),
/// unlike the `sent`/`received` shapes above. Its amount has no forced
/// 2-decimal-place formatting and "RWF" appears *before* the number
/// rather than after, so it needs its own amount/date extractors
/// rather than reusing `_amountField`/the two date patterns below.
///
/// Deliberately NOT modeled here (confirmed real, correctly left
/// unparsed): card-authorization notices ("Auth for card ...Amt: USD
/// ..." — a foreign-currency pending hold, not a settled RWF
/// transaction), zero-amount auto-charges ("Debit for card ...Amt:
/// 0.00"), agent-withdrawal codes ("Use the code X to withdraw..." — no
/// amount, nothing has moved yet), and "Confirmed. Request to send ...
/// has been received for processing" (explicitly not yet completed —
/// booking it now risks double-counting if/when a completion SMS
/// follows). All of these fall through to the unparsed-message review
/// queue, which is the correct outcome for a not-yet-settled or
/// non-transactional notice.
class EquityBankParser extends MomoParser {
  @override
  String get providerCode => 'equity_bank_rw';

  static const _amountGroup = r'([\d,]+\.\d{2})\s*RWF';

  static final _sentIntro =
      RegExp(r'RWF\s+(?:was|has\s+been)\s+successfully\s+sent\s+to', caseSensitive: false);
  static final _receivedIntro = RegExp(r'you\s+have\s+received', caseSensitive: false);
  static final _debitedIntro =
      RegExp(r'you\s+have\s+been\s+debited\s+with\s+RWF', caseSensitive: false);
  static final _creditedIntro =
      RegExp(r'you\s+have\s+been\s+credited\s+with\s+RWF', caseSensitive: false);

  static final _amountField = RegExp(_amountGroup, caseSensitive: false);

  // Debit/credit shape: "debited with RWF 1000000 Charge 0 ref ..." —
  // no decimals, no trailing "RWF".
  static final _statementAmountField =
      RegExp(r'(?:debited|credited)\s+with\s+RWF\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
  static final _statementRefField = RegExp(r'\bref\s+(\w+)', caseSensitive: false);
  static final _statementBranchField =
      RegExp(r'from\s+([A-Z][A-Z\s]+?)\s+On:', caseSensitive: false);
  static final _statementBalanceField =
      RegExp(r'balance\s+([\d,]+(?:\.\d+)?)', caseSensitive: false);
  // "On: 19-Jan-26 07:21:04"
  static final _statementDate = RegExp(
    r'On:\s*(\d{1,2})-(\w{3})-(\d{2})\s+(\d{1,2}):(\d{2}):(\d{2})',
    caseSensitive: false,
  );

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

    // The debit/credit bank-statement shape has its own amount/date
    // format entirely (no forced 2-decimal "RWF"-suffixed amount, a
    // "DD-Mon-YY HH:MM:SS" date) — checked first and returned early so
    // it never falls through to the sent/received amount extraction
    // below, which would not match it anyway.
    if (_debitedIntro.hasMatch(normalized) || _creditedIntro.hasMatch(normalized)) {
      final amount = _toDouble(_statementAmountField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;

      return ParsedTransaction(
        type: _debitedIntro.hasMatch(normalized)
            ? TransactionType.bankTransfer
            : TransactionType.received,
        amount: amount,
        counterparty: _statementBranchField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: _statementRefField.firstMatch(normalized)?.group(1),
        balanceAfter: _toDouble(_statementBalanceField.firstMatch(normalized)?.group(1)),
        timestamp: _extractStatementTimestamp(normalized) ?? receivedAt ?? DateTime.now(),
      );
    }

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

  static DateTime? _extractStatementTimestamp(String body) {
    final match = _statementDate.firstMatch(body);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = _months[match.group(2)!.toLowerCase()];
    if (month == null) return null;
    final year = 2000 + int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    try {
      return DateTime(year, month, day, hour, minute, second);
    } on ArgumentError {
      return null;
    }
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
