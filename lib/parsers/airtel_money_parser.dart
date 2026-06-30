import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses Airtel Money (Rwanda) notification SMS.
///
/// Built directly from real message text — see
/// `docs/SMS_PATTERN_LIBRARY.md` (Airtel section) and the redacted
/// fixtures in `test/fixtures/airtel_money/`. Airtel's real traffic is
/// confirmed to be *less* internally consistent than MTN's: the `sent`
/// shape alone has at least three field-name variants across real
/// messages (`Amount RWF X. CHARGES RWF Y`, `Amount XCHARGES RWF Y` with
/// no space/no RWF-before-number, and `Amt RWF X. Fee RWF Y. BAL RWF
/// Z`). Every field below is matched independently and tolerantly for
/// exactly this reason — a single strict sequential pattern would only
/// ever match whichever variant it was written against.
class AirtelMoneyParser extends MomoParser {
  @override
  String get providerCode => 'airtel_money_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)';

  static final _receivedIntro = RegExp(r'you\s+have\s+received', caseSensitive: false);
  static final _sentIntro =
      RegExp(r'money\s+successfully\s+sent\s+to', caseSensitive: false);
  static final _paymentIntro = RegExp(r'payment\s+of\s+RWF', caseSensitive: false);
  static final _bundleIntro =
      RegExp(r'purchase\s+of\s+bundle\s+of', caseSensitive: false);

  // Amount extraction differs by shape: `received`/`payment` say
  // "RWF AMOUNT"; `sent` says "Amount(?: RWF)? AMOUNT" (with or without
  // "RWF" and with or without a space before the number, confirmed
  // real); `bundle` says "Bundle of Rwf AMOUNT".
  static final _amountAfterRwf =
      RegExp('RWF\\s*$_amountGroup', caseSensitive: false);
  static final _amountField =
      RegExp('Amount\\s*(?:RWF)?\\s*$_amountGroup', caseSensitive: false);
  static final _amtField = RegExp('Amt\\s+RWF\\s*$_amountGroup', caseSensitive: false);
  static final _bundleAmountField =
      RegExp('Bundle\\s+of\\s+Rwf\\s*$_amountGroup', caseSensitive: false);

  static final _feeField =
      RegExp('(?:CHARGES|Fee)\\s+RWF\\s*$_amountGroup', caseSensitive: false);
  static final _balanceField = RegExp(
    'NEW\\s*BALANCE\\s*is\\s*RWF\\s*$_amountGroup',
    caseSensitive: false,
  );
  static final _balField = RegExp('BAL\\s+RWF\\s*$_amountGroup', caseSensitive: false);

  static final _txnIdField =
      RegExp(r'T[Xx][Nn]\s*ID\s*[:(]?\s*([\w.]+)', caseSensitive: false);

  static final _receivedFromField = RegExp(
    r'received\s+RWF\s*[\d,.]+\s+from\s+(.+?)\s+in\s+MTN\s+RWANDA',
    caseSensitive: false,
    dotAll: true,
  );
  static final _sentToField = RegExp(
    r'sent\s+to\s+(.+?)\s+(?:in\s+MTN|Amount|Amt)',
    caseSensitive: false,
    dotAll: true,
  );
  static final _paymentToField = RegExp(
    r'RWF\s*[\d,.]+\s+to\s+(.+?)\s+successful',
    caseSensitive: false,
    dotAll: true,
  );

  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    final timestamp = receivedAt ?? DateTime.now();
    final txRef = _txnIdField.firstMatch(normalized)?.group(1);

    if (_receivedIntro.hasMatch(normalized)) {
      final amount = _toDouble(_amountAfterRwf.firstMatch(normalized)?.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.received,
        amount: amount,
        counterparty: _receivedFromField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        balanceAfter: _toDouble(_balanceField.firstMatch(normalized)?.group(1)),
        timestamp: timestamp,
      );
    }

    if (_sentIntro.hasMatch(normalized)) {
      // Try each confirmed real amount-field variant in turn.
      final amount = _toDouble(_amountField.firstMatch(normalized)?.group(1)) ??
          _toDouble(_amtField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.sent,
        amount: amount,
        counterparty: _sentToField.firstMatch(normalized)?.group(1)?.trim(),
        fee: _toDouble(_feeField.firstMatch(normalized)?.group(1)) ?? 0,
        txRef: txRef,
        balanceAfter: _toDouble(_balanceField.firstMatch(normalized)?.group(1)) ??
            _toDouble(_balField.firstMatch(normalized)?.group(1)),
        timestamp: timestamp,
      );
    }

    if (_paymentIntro.hasMatch(normalized)) {
      final amount = _toDouble(_amountAfterRwf.firstMatch(normalized)?.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.payment,
        amount: amount,
        counterparty: _paymentToField.firstMatch(normalized)?.group(1)?.trim(),
        txRef: txRef,
        balanceAfter: _toDouble(_balanceField.firstMatch(normalized)?.group(1)),
        timestamp: timestamp,
      );
    }

    if (_bundleIntro.hasMatch(normalized)) {
      final amount = _toDouble(_bundleAmountField.firstMatch(normalized)?.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.airtime,
        amount: amount,
        txRef: txRef,
        balanceAfter: _toDouble(_balanceField.firstMatch(normalized)?.group(1)),
        timestamp: timestamp,
      );
    }

    return null;
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
