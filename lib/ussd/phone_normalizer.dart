/// Normalizes and validates a Rwandan mobile number for use in the
/// recipient slot of a `*182#` USSD send-money code (spec Phase 9).
///
/// Confirmed real bug this fixes: no normalization existed anywhere in
/// the Pay flow (contact picker only did `.trim()`, manual entry and
/// frequent-code selection did nothing at all), so a malformed or
/// merged contact record — or a free-text counterparty string picked
/// from Frequent codes — could flow straight into `UssdBuilder`
/// unsanitized, producing a broken code like
/// `*182*8*1*627434673883892627492*100#`.
class PhoneNormalizer {
  PhoneNormalizer._();

  static final _digitsAndPlus = RegExp(r'[^\d+]');
  static final _localShape = RegExp(r'^0\d{9}$');

  /// Strips everything except digits and `+`, recognizes the real
  /// Rwandan mobile shapes (`0XXXXXXXXX`, 9-digit with no leading 0,
  /// `+250XXXXXXXXX`, `250XXXXXXXXX`), and returns the canonical
  /// 10-digit `0XXXXXXXXX` form MTN's own *182# menu expects.
  ///
  /// Returns null — never throws — for anything that doesn't match one
  /// of those shapes, including garbage far too long/short to be a
  /// real number. Callers must surface a user-facing error rather than
  /// ever passing a null result on to [UssdBuilder].
  static String? normalizeRwandanMobile(String raw) {
    final cleaned = raw.replaceAll(_digitsAndPlus, '');
    final digitsOnly = cleaned.replaceAll('+', '');

    String? local;
    if (digitsOnly.length == 12 && digitsOnly.startsWith('250')) {
      local = '0${digitsOnly.substring(3)}';
    } else if (digitsOnly.length == 10 && digitsOnly.startsWith('0')) {
      local = digitsOnly;
    } else if (digitsOnly.length == 9 && !digitsOnly.startsWith('0')) {
      local = '0$digitsOnly';
    }

    if (local == null || !_localShape.hasMatch(local)) return null;
    return local;
  }
}
