import '../data/database.dart';
import 'momo_parser.dart';
import 'parsed_transaction.dart';

/// Parses MoKash (Rwanda) notification SMS — MTN's savings/micro-loan
/// sub-wallet, sent from the `Y'ello` sender (distinct from MTN MoMo's
/// own `M-Money`/`MTN`/`MoMo`/`MTNRWANDA` senders, so no disambiguator
/// against `mtn_momo_rw` is needed — see `AppDatabase._seedProviders`).
///
/// Two confirmed real shapes move money in opposite directions between
/// MoKash and the main MoMo wallet:
///   - "You have transferred RWF X from your Mokash account on ... .
///     Mokash balance is RWF Y. Ref Z" — money leaving MoKash, modeled
///     as [TransactionType.withdrawal] (MoKash's own balance decreases).
///   - "RWF X transferred to your Mokash account on ... . Your new
///     Mokash account balance is RWF Y.Ref Z" — money entering MoKash,
///     modeled as [TransactionType.deposit].
/// Both report a running "Mokash balance"/"Mokash account balance" —
/// this is MoKash's own sub-wallet balance, not the main MoMo balance,
/// so it must never be merged into the same [Accounts] row as
/// `mtn_momo_rw`.
class MokashParser extends MomoParser {
  @override
  String get providerCode => 'mokash_rw';

  static const _amountGroup = r'([\d,]+(?:\.\d+)?)';

  static final _fromMokashIntro = RegExp(
    r'transferred\s+RWF\s*' '$_amountGroup' r'\s+from\s+your\s+Mokash\s+account',
    caseSensitive: false,
  );
  static final _toMokashIntro = RegExp(
    r'RWF\s*' '$_amountGroup' r'\s+transferred\s+to\s+your\s+Mokash\s+account',
    caseSensitive: false,
  );

  static final _balanceField = RegExp(
    r'Mokash\s+(?:account\s+)?balance\s+is\s+RWF\s*' '$_amountGroup',
    caseSensitive: false,
  );
  static final _refField = RegExp(r'Ref\s+(\w+)', caseSensitive: false);

  // Confirmed real: "transferred from" puts the date first, then time
  // ("on 16/07/2026 at 4:45 PM"); "transferred to" puts the time first,
  // then date ("on 0:36 PM at 10/07/2026") — a genuinely different
  // token order, not just cosmetic, so each is its own pattern rather
  // than one regex trying to fit both.
  static final _dateThenTime = RegExp(
    r'on\s+(\d{1,2})/(\d{1,2})/(\d{4})\s+at\s+(\d{1,2}):(\d{2})\s*(AM|PM)?',
    caseSensitive: false,
  );
  static final _timeThenDate = RegExp(
    r'on\s+(\d{1,2}):(\d{2})\s*(AM|PM)?\s+at\s+(\d{1,2})/(\d{1,2})/(\d{4})',
    caseSensitive: false,
  );

  @override
  ParsedTransaction? tryParse(String body, {DateTime? receivedAt}) {
    final normalized = body.replaceAll('\r\n', '\n').trim();
    final txRef = _refField.firstMatch(normalized)?.group(1);
    final balanceAfter = _toDouble(_balanceField.firstMatch(normalized)?.group(1));
    final timestamp = _extractTimestamp(normalized) ?? receivedAt ?? DateTime.now();

    final outMatch = _fromMokashIntro.firstMatch(normalized);
    if (outMatch != null) {
      final amount = _toDouble(outMatch.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.withdrawal,
        amount: amount,
        txRef: txRef,
        balanceAfter: balanceAfter,
        timestamp: timestamp,
      );
    }

    final inMatch = _toMokashIntro.firstMatch(normalized);
    if (inMatch != null) {
      final amount = _toDouble(inMatch.group(1));
      if (amount == null) return null;
      return ParsedTransaction(
        type: TransactionType.deposit,
        amount: amount,
        txRef: txRef,
        balanceAfter: balanceAfter,
        timestamp: timestamp,
      );
    }

    return null;
  }

  static DateTime? _extractTimestamp(String body) {
    final dateThenTime = _dateThenTime.firstMatch(body);
    if (dateThenTime != null) {
      return _buildDateTime(
        day: dateThenTime.group(1)!,
        month: dateThenTime.group(2)!,
        year: dateThenTime.group(3)!,
        hour: dateThenTime.group(4)!,
        minute: dateThenTime.group(5)!,
        meridiem: dateThenTime.group(6),
      );
    }

    final timeThenDate = _timeThenDate.firstMatch(body);
    if (timeThenDate != null) {
      return _buildDateTime(
        hour: timeThenDate.group(1)!,
        minute: timeThenDate.group(2)!,
        meridiem: timeThenDate.group(3),
        day: timeThenDate.group(4)!,
        month: timeThenDate.group(5)!,
        year: timeThenDate.group(6)!,
      );
    }

    return null;
  }

  static DateTime? _buildDateTime({
    required String day,
    required String month,
    required String year,
    required String hour,
    required String minute,
    String? meridiem,
  }) {
    var h = int.parse(hour);
    final m = meridiem?.toUpperCase();
    if (m == 'PM' && h != 12) h += 12;
    if (m == 'AM' && h == 12) h = 0;
    try {
      return DateTime(int.parse(year), int.parse(month), int.parse(day), h, int.parse(minute));
    } on ArgumentError {
      return null;
    }
  }

  static double? _toDouble(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}
