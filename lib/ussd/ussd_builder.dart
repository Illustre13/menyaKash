/// The provider whose USSD menu a code should use. Confirmed real
/// codes (spec #7 research, KTPress Jan 2026 + RURA's Jan 14 2026
/// harmonization directive, effective Feb 15 2026): MTN MoMo is
/// `*182#`, Airtel Money is `*500#`. RURA's directive requires these to
/// eventually work identically across networks, but as of writing that
/// rollout isn't guaranteed complete on every device/carrier
/// combination — this app still picks the code by the account's real
/// provider rather than assuming universal interoperability, since
/// dialing the wrong network's code for a till/merchant payment can
/// simply fail rather than degrade gracefully.
enum UssdProvider { mtnMomo, airtelMoney }

/// Builds *182#/*500# style USSD strings for MoMo actions in Rwanda.
///
/// NOTE: The exact menu structure below (option numbers/order) is each
/// provider's real public USSD menu convention as of app design time,
/// but providers can change menu structure without notice — verify on
/// a real device before shipping and adjust the option codes here if
/// needed. This only ever builds a string and hands it to the dialer;
/// it never programmatically drives a USSD session.
///
/// Deliberately does NOT hardcode menu-nested paths this app couldn't
/// verify against a reliable source (e.g. a specific digit sequence
/// for "pay EUCL electricity" or "pay WASAC water" inside *182#'s own
/// menu) — getting a middle digit wrong in a financial app risks
/// sending a real payment to the wrong destination. Where research
/// only confirmed a top-level code, [AdvancedAction] in pay_screen.dart
/// opens that root code and lets the user navigate the real on-screen
/// menu themselves, rather than guessing a full digit sequence.
class UssdBuilder {
  UssdBuilder._();

  static String _root(UssdProvider provider) => switch (provider) {
        UssdProvider.mtnMomo => '*182',
        UssdProvider.airtelMoney => '*500',
      };

  /// Send money to another MoMo number: *182*1*1*<phone>*<amount>#
  /// (Airtel Money's own "send money" menu position is unconfirmed
  /// against a reliable source as of writing — defaults to MTN's menu
  /// shape until real Airtel evidence is gathered, consistent with
  /// this project's confirmed-real-evidence-only convention for every
  /// other provider integration).
  ///
  /// [phoneNumber] must already be normalized to the canonical
  /// `0XXXXXXXXX` shape via `PhoneNormalizer.normalizeRwandanMobile`
  /// before calling this — this method does not itself sanitize input,
  /// it only builds the string. The assert below is a defensive second
  /// line of guard against a future call site bypassing normalization
  /// (stripped in release builds, so it can't introduce a new
  /// release-mode failure path itself).
  static String sendMoney({
    required String phoneNumber,
    required int amountRwf,
    UssdProvider provider = UssdProvider.mtnMomo,
  }) {
    assert(
      RegExp(r'^0\d{9}$').hasMatch(phoneNumber),
      'sendMoney expects an already-normalized 0XXXXXXXXX number; got '
      '"$phoneNumber". Normalize with PhoneNormalizer first.',
    );
    return '${_root(provider)}*1*1*$phoneNumber*$amountRwf#';
  }

  /// Pay a merchant/till code: *182*8*1*<code>*<amount>#
  static String payMerchant({
    required String tillCode,
    required int amountRwf,
    UssdProvider provider = UssdProvider.mtnMomo,
  }) {
    return '${_root(provider)}*8*1*$tillCode*$amountRwf#';
  }

  /// Buy airtime for own line: *182*2*1*<amount>#
  static String buyAirtime({
    required int amountRwf,
    UssdProvider provider = UssdProvider.mtnMomo,
  }) {
    return '${_root(provider)}*2*1*$amountRwf#';
  }

  /// Check MoMo balance: *182*6*1#
  static String checkBalance({UssdProvider provider = UssdProvider.mtnMomo}) =>
      '${_root(provider)}*6*1#';

  /// Opens the provider's own root USSD menu with no pre-selected
  /// option, e.g. `*182#` — the honest fallback for any real service
  /// (electricity, water, bundles, Mokash) whose exact menu-nested
  /// digit sequence this app hasn't verified against a reliable
  /// source. The user picks the real option from the real on-screen
  /// menu themselves.
  static String openMenu({UssdProvider provider = UssdProvider.mtnMomo}) => '${_root(provider)}#';
}
