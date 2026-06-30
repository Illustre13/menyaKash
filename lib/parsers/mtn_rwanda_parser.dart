import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses MTN Mobile Money (Rwanda) notification SMS.
///
/// Every regex below was built directly from real message text — see
/// `docs/SMS_PATTERN_LIBRARY.md` (MTN section) and the redacted fixtures
/// in `test/fixtures/mtn_rwanda/`, both sourced from a genuine
/// 8,364-message device export (`docs/AUDIT_PHASE_0.md`). This replaced
/// an earlier version built from guesses with zero real verification —
/// none of that guessed shape matched anything in the real export.
///
/// Real MTN Rwanda MoMo traffic uses at least seven distinct message
/// shapes with genuinely different field wording (not just different
/// values) — `received` masks the sender's phone, `sent` doesn't;
/// `payment` uses `TxId:`, `withdrawal`/`received` use `Financial
/// Transaction Id:`; the date format is `YYYY-MM-DD HH:MM:SS`, not
/// `DD/MM/YYYY` as an earlier guess assumed. Each field is still matched
/// independently (not one strict sequential regex per type) since real
/// messages don't guarantee field order — see the design note this
/// class always had, which turned out to matter even more than expected
/// once real Airtel data showed the same field appearing in different
/// positions across otherwise-identical message types.
///
/// No real "reversed" MTN MoMo message was found anywhere in the export
/// — the v1 `reversed` type/regex/fixture were pure speculation and have
/// been removed. If a real reversal message is ever observed, add its
/// fixture to `test/fixtures/mtn_rwanda/` first, then extend this parser.
class MtnRwandaParser extends MomoParser {
  @override
  String get providerCode => 'mtn_momo_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)\s*RWF';

  // Transaction-type detectors: just enough of the sentence to identify
  // *which* real template this is.
  static final _receivedIntro = RegExp(r'you\s+have\s+received', caseSensitive: false);
  static final _sentIntro = RegExp(r'RWF\s+transferred\s+to', caseSensitive: false);
  static final _paymentIntro = RegExp(r'your\s+payment\s+of', caseSensitive: false);
  static final _merchantDebitIntro =
      RegExp(r'a\s+transaction\s+of\s+[\d,]', caseSensitive: false);
  static final _withdrawalIntro =
      RegExp(r'have\s+via\s+agent.*?withdrawn', caseSensitive: false, dotAll: true);
  static final _depositIntro = RegExp(r'a\s+bank\s+deposit\s+of', caseSensitive: false);
  static final _failedIntro = RegExp(r'\bfailed\s+at\b', caseSensitive: false);

  // Independent field extractors — each looks for its own field anywhere
  // in the message, regardless of what comes before or after it.
  //
  // NOTE: these interpolate _amountGroup via '...' '$_amountGroup' string
  // concatenation (adjacent raw + interpolated literals), NOT r'...$var'
  // — a raw string never interpolates, so r'...$_amountGroup' would embed
  // the literal text "$_amountGroup" in the pattern instead of its value.
  static final _amountField = RegExp(_amountGroup, caseSensitive: false);
  static final _feeField =
      RegExp(r'fee\s+(?:was|paid)[:\s]*' '$_amountGroup', caseSensitive: false);
  static final _balanceField = RegExp(
    r'(?:new\s+balance|NEW\s+BALANCE)\s*[:\s]+' '$_amountGroup',
    caseSensitive: false,
  );
  // "Financial Transaction Id: 123." or "TxId: 123." or "TxId:123*S*".
  static final _txRefField = RegExp(
    r'(?:Financial\s+Transaction\s+Id|TxId)\s*[:.]?\s*(\w+)',
    caseSensitive: false,
  );

  /// `received`: "...from NAME (MASKED_PHONE) on your mobile money..."
  static final _receivedFromField = RegExp(
    r'from\s+(.+?)\s*\([\d*]+\)\s+on\s+your\s+mobile\s+money',
    caseSensitive: false,
    dotAll: true,
  );

  /// `sent`: "...transferred to NAME (PHONE) from ACCOUNT at TIMESTAMP"
  static final _sentToField = RegExp(
    r'transferred\s+to\s+(.+?)\s*\([\d]+\)\s+from',
    caseSensitive: false,
    dotAll: true,
  );

  /// `payment`: "...payment of AMOUNT RWF to MERCHANT has been completed"
  /// — the merchant span (name + trailing account code, one opaque blob
  /// by design at this layer; splitting it is Phase 4's job, not the
  /// parser's) runs up to "has been completed".
  static final _paymentToField = RegExp(
    r'RWF\s+to\s+(.+?)\s+has\s+been\s+completed',
    caseSensitive: false,
    dotAll: true,
  );

  /// Merchant-debit (`*164*S*...`): "...transaction of AMOUNT RWF by
  /// MERCHANT  on your MOMO account..." — note the real double space
  /// before "on" in every confirmed sample; kept optional (`\s+`, not a
  /// literal double space) so a single-space variant still matches.
  static final _merchantDebitByField = RegExp(
    r'RWF\s+by\s+(.+?)\s+on\s+your\s+MOMO\s+account',
    caseSensitive: false,
    dotAll: true,
  );

  /// `withdrawal`: "...via agent: NAME (PHONE), withdrawn..."
  static final _agentField = RegExp(
    r'via\s+agent:\s*(.+?)\s*\([\d]+\),\s*withdrawn',
    caseSensitive: false,
    dotAll: true,
  );

  /// Matches the real embedded timestamp: "at YYYY-MM-DD HH:MM:SS" (also
  /// covers the bare "on YYYY-MM-DD..." phrasing some shapes use instead
  /// of "at"). Every confirmed real MTN message uses this ISO-ish
  /// year-first order, never `DD/MM/YYYY` as an earlier guessed version
  /// assumed.
  static final _embeddedDate = RegExp(
    r'(?:at|on)\s+(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    caseSensitive: false,
  );

  /// [receivedAt] is when the SMS itself landed in the inbox (the
  /// telephony plugin's SmsColumn.DATE) — used as the fallback timestamp
  /// when the message body's own date can't be parsed. Without this,
  /// every transaction would be mis-dated to "now" at scan time, which
  /// would make weekly/monthly/quarterly/yearly reports meaningless for
  /// historical data.
  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    final timestamp = _extractTimestamp(normalized) ?? receivedAt ?? DateTime.now();
    final amount = _toDouble(_amountField.firstMatch(normalized)?.group(1));
    if (amount == null) return null;

    final balance = _toDouble(_balanceField.firstMatch(normalized)?.group(1));
    final txRef = _txRefField.firstMatch(normalized)?.group(1);

    // `failed` must be checked before `payment`/merchant-debit — a
    // failed transaction's body still contains "for MERCHANT" and an
    // amount, but it never completed, so it must not be recorded as a
    // real payment. There's no TransactionType for "failed" yet (no
    // real successful-negative-value case exists to model against);
    // returning null here routes it to the unparsed-message review
    // queue instead of guessing at a type, per this app's fail-safe
    // design principle.
    if (_failedIntro.hasMatch(normalized)) {
      return null;
    }

    if (_receivedIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.received,
        amount: amount,
        counterparty: _receivedFromField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_sentIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.sent,
        amount: amount,
        counterparty: _sentToField.firstMatch(normalized)?.group(1)?.trim(),
        fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_paymentIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.payment,
        amount: amount,
        counterparty: _paymentToField.firstMatch(normalized)?.group(1)?.trim(),
        fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_merchantDebitIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.payment,
        amount: amount,
        counterparty: _merchantDebitByField.firstMatch(normalized)?.group(1)?.trim(),
        fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_withdrawalIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.withdrawal,
        amount: amount,
        counterparty: _agentField.firstMatch(normalized)?.group(1)?.trim(),
        fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_depositIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.deposit,
        amount: amount,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    // "Airtime" is a `payment` to the literal merchant name "Airtime"
    // in the same TxId-based shape as any other merchant payment — not
    // a distinct real message shape, so it's naturally covered above
    // when `counterparty` extraction sees "to Airtime with token". No
    // separate airtime branch is needed here; the airtime.txt fixture
    // exists to prove this specific case parses via `_paymentIntro`.

    return null;
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
