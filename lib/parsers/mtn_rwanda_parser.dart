import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses MTN Mobile Money (Rwanda) notification SMS.
///
/// IMPORTANT — read before trusting this in production:
/// The regex patterns below were NOT built from verbatim MTN Rwanda SMS
/// (none could be sourced from public/web research at design time). They
/// follow the general MTN MoMo boilerplate structure seen across markets
/// and in comparable providers (amount, optional fee, counterparty name
/// and/or phone number, a transaction id, and a running balance), but
/// exact wording, punctuation, and field order WILL differ from the real
/// thing until verified.
///
/// Design note: each field (amount, counterparty, fee, TxId, balance) is
/// matched independently rather than with one strict left-to-right
/// sequential regex per transaction type. Real MTN messages are not
/// guaranteed to lay out fields in any particular order (e.g. the
/// balance line can appear before or after the TxId line), and a single
/// sequential pattern silently fails to match the moment two fields
/// swap order — independent field extraction is robust to that.
///
/// Before relying on this parser:
///   1. Collect 5-10 real MTN Rwanda MoMo SMS from an actual device,
///      one per transaction type, with amounts/names redacted if sharing.
///   2. Drop them into test/fixtures/mtn_rwanda/ and adjust the regexes
///      below (and knownSenders) until every fixture parses correctly.
///   3. Anything that still doesn't match falls through to the
///      UnparsedMessages review queue rather than being silently dropped
///      — so incorrect guesses here are safe, not silently lossy.
class MtnRwandaParser extends MomoParser {
  @override
  String get providerId => 'mtn_rw';

  @override
  Set<String> get knownSenders => const {'M-Money', 'MTN', 'MoMo'};

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)\s*RWF';

  // Transaction-type detectors: just enough of the sentence to identify
  // *which* template this is, not the full field layout.
  static final _receivedIntro = RegExp(r'you\s+have\s+received', caseSensitive: false);
  static final _sentIntro =
      RegExp(r'(?:you\s+have\s+)?(?:transferred|sent)\s+[\d,]', caseSensitive: false);
  static final _paymentIntro = RegExp(r'your\s+payment\s+of', caseSensitive: false);
  static final _withdrawalIntro = RegExp(r'(?:you\s+have\s+)?withdrawn', caseSensitive: false);
  static final _depositIntro = RegExp(r'(?:you\s+have\s+)?deposited', caseSensitive: false);
  static final _airtimeIntro =
      RegExp(r'(?:airtime|bundle)\s+purchase\s+of', caseSensitive: false);
  static final _reversed = RegExp(r'reversed|has\s+been\s+cancelled', caseSensitive: false);

  // Independent field extractors — each looks for its own field anywhere
  // in the message, regardless of what comes before or after it.
  //
  // NOTE: these interpolate _amountGroup via '...' '$_amountGroup' string
  // concatenation (adjacent raw + interpolated literals), NOT r'...$var'
  // — a raw string never interpolates, so r'...$_amountGroup' would embed
  // the literal text "$_amountGroup" in the pattern instead of its value.
  static final _amountField = RegExp(_amountGroup, caseSensitive: false);
  static final _feeField =
      RegExp(r'(?:fee|charge)\s*[:.]?\s*' '$_amountGroup', caseSensitive: false);
  static final _balanceField = RegExp(
    r'(?:new\s+balance|bal(?:ance)?)\s*[:.]?\s*' '$_amountGroup',
    caseSensitive: false,
  );
  static final _txRefField =
      RegExp(r'(?:TxId|Transaction\s*Id|Ref)\s*[:.]?\s*(\w+)', caseSensitive: false);
  static final _fromField =
      RegExp(r'from\s+(.+?)(?:\s*\(|\s+on\s|\.|$)', caseSensitive: false, dotAll: true);
  static final _toField =
      RegExp(r'\bto\s+(.+?)(?:\s*\(|\s+on\s|\.|$)', caseSensitive: false, dotAll: true);
  static final _agentField = RegExp(
    r'(?:from\s+agent|at)\s+(.+?)(?:\s*\(|\s+on\s|\.|$)',
    caseSensitive: false,
    dotAll: true,
  );

  /// Matches the "on DD/MM/YYYY HH:MM:SS" (or without seconds) timestamp
  /// embedded in the SMS body, e.g. "on 08/07/2026 14:32:10".
  static final _embeddedDate = RegExp(
    r'on\s+(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    caseSensitive: false,
  );

  /// [receivedAt] is when the SMS itself landed in the inbox (the
  /// telephony plugin's SmsColumn.DATE) — used as the fallback timestamp
  /// when the message body's own "on DD/MM/YYYY HH:MM" can't be parsed.
  /// Without this fallback, every transaction would be mis-dated to
  /// "now" at scan time, which would make weekly/monthly/quarterly/yearly
  /// reports meaningless for historical data.
  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    final timestamp = _extractTimestamp(normalized) ?? receivedAt ?? DateTime.now();
    final amount = _toDouble(_amountField.firstMatch(normalized)?.group(1));

    if (_reversed.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.reversed,
        amount: amount ?? 0,
        timestamp: timestamp,
      );
    }

    if (amount == null) return null;
    final balance = _toDouble(_balanceField.firstMatch(normalized)?.group(1));
    final txRef = _txRefField.firstMatch(normalized)?.group(1);

    if (_receivedIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.received,
        amount: amount,
        counterparty: _fromField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    if (_sentIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.sent,
        amount: amount,
        counterparty: _toField.firstMatch(normalized)?.group(1)?.trim(),
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
        counterparty: _toField.firstMatch(normalized)?.group(1)?.trim(),
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

    if (_airtimeIntro.hasMatch(normalized)) {
      return ParsedTransaction(
        type: TransactionType.airtime,
        amount: amount,
        balanceAfter: balance,
        timestamp: timestamp,
      );
    }

    return null;
  }

  static DateTime? _extractTimestamp(String body) {
    final match = _embeddedDate.firstMatch(body);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
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
