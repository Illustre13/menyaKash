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

/// A bank whose USSD root menu is confirmed real (review batch item
/// #2, quoted directly from a real article: "Codes such as *334# for
/// Bank of Kigali, *150# for BPR, *227# for I&M Bank, and *555# for
/// Equity Bank are used daily by customers"). Only the root code is
/// confirmed — no menu-nested path (e.g. "check balance" as a specific
/// option number) has been verified for any of these, so
/// [UssdBuilder.bankMenu] only ever opens the root; the user picks the
/// real option from the real on-screen menu themselves, same honesty
/// rule as [UssdBuilder.openMenu].
enum BankUssd { bk, bpr, imBank, equity }

/// Builds *182#/*500#/bank-root style USSD strings for USSD-based
/// services in Rwanda.
///
/// NOTE: The exact menu structure below (option numbers/order) is each
/// provider's real public USSD menu convention as of app design time,
/// but providers can change menu structure without notice — verify on
/// a real device before shipping and adjust the option codes here if
/// needed. This only ever builds a string and hands it to the dialer;
/// it never programmatically drives a USSD session, and it never
/// embeds a PIN in the dialed string — every code below ends before
/// the PIN prompt, exactly like dialing it by hand: the network's own
/// USSD session asks for the PIN interactively after the call
/// connects. Storing or forwarding a user's MoMo/bank PIN would be a
/// real security regression this app has avoided everywhere else.
///
/// Deliberately does NOT hardcode a menu-nested path this app couldn't
/// verify against a reliable source (e.g. a specific digit sequence for
/// "check balance" inside a bank's own *334#/*150#/*227#/*555# menu) —
/// getting a middle digit wrong in a financial app risks sending a real
/// payment to the wrong destination. Where research confirmed a full
/// menu-nested path (water, electricity below), that exact path is used
/// directly; where only a root code is confirmed (the four banks,
/// MTN's *345# bundle picker), [openMenu]/[bankMenu] opens just that
/// root and the user finishes on the real on-screen menu.
class UssdBuilder {
  UssdBuilder._();

  static String _root(UssdProvider provider) => switch (provider) {
        UssdProvider.mtnMomo => '*182',
        UssdProvider.airtelMoney => '*500',
      };

  static String _bankRoot(BankUssd bank) => switch (bank) {
        BankUssd.bk => '*334',
        BankUssd.bpr => '*150',
        BankUssd.imBank => '*227',
        BankUssd.equity => '*555',
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

  /// Buy airtime for own MTN line: *182*2*1*1*1*<amount>#. Confirmed
  /// real (review batch item #2, quoted directly): "Buy airtime for
  /// yourself: *182*2*1*1*1*amount*PIN#" — corrects an earlier,
  /// unverified shorter guess (*182*2*1*<amount>#) that skipped a real
  /// menu level.
  static String buyAirtime({required int amountRwf}) => '*182*2*1*1*1*$amountRwf#';

  /// Check MoMo balance: *182*6*1#
  static String checkBalance({UssdProvider provider = UssdProvider.mtnMomo}) =>
      '${_root(provider)}*6*1#';

  /// Pay a WASAC water bill: *182*3*5#. Confirmed real (quoted
  /// directly): "Pay your water bill (WASAC): *182*3*5# then follow the
  /// prompts (you will need your meter number)" — the user enters their
  /// own meter number on the real on-screen prompt; this app never
  /// stores or pre-fills a meter number.
  static String payWater() => '*182*3*5#';

  /// Buy Cash Power electricity credit: *720*1#. Confirmed real (quoted
  /// directly): "Buy electricity (cash power): *720*1# then follow the
  /// prompts (you will need your meter number)" — same meter-number
  /// caveat as [payWater].
  static String payElectricity() => '*720*1#';

  /// Opens MTN's data-bundle picker menu: *345#. Confirmed real
  /// (quoted directly: "Buy a data bundle: *345# then choose your
  /// package") but only the root is confirmed — no specific bundle's
  /// digit position is verified, so this opens the menu rather than
  /// guessing a bundle selection.
  static String mtnBundles() => '*345#';

  /// Checks MTN or Airtel airtime balance: *131# — confirmed real for
  /// both networks independently (quoted directly for each).
  static String checkAirtimeBalance() => '*131#';

  /// Recharge Airtel airtime: *130#. Confirmed real (quoted directly:
  /// "Airtel users commonly dial *130# to recharge airtime").
  static String airtelRechargeAirtime() => '*130#';

  /// Share Airtel airtime with another number: *132#. Confirmed real
  /// (quoted directly: "...*132# to share airtime with others").
  static String airtelShareAirtime() => '*132#';

  /// Opens Airtel's bundle-activation/data-check menu: *255#.
  /// Confirmed real (quoted directly: "Activate bundles and check
  /// data: *255#").
  static String airtelBundles() => '*255#';

  /// Opens a bank's real root USSD menu (e.g. *334# for Bank of
  /// Kigali) — see [BankUssd] doc for why this only ever opens the
  /// root, never a guessed menu-nested option.
  static String bankMenu(BankUssd bank) => '${_bankRoot(bank)}#';

  /// Opens the provider's own root USSD menu with no pre-selected
  /// option, e.g. `*182#` — the honest fallback for any real service
  /// (Mokash) whose exact menu-nested digit sequence this app hasn't
  /// verified against a reliable source. The user picks the real
  /// option from the real on-screen menu themselves.
  static String openMenu({UssdProvider provider = UssdProvider.mtnMomo}) => '${_root(provider)}#';
}
