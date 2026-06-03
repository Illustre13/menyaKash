/// Builds *182...# style USSD strings for MTN Rwanda MoMo actions.
///
/// NOTE: The exact *182# menu structure below (option numbers/order) is
/// MTN Rwanda's real public USSD menu convention as of app design time,
/// but MTN can change menu structure without notice — verify on a real
/// device before shipping and adjust the option codes here if needed.
/// This only ever builds a string and hands it to the dialer; it never
/// programmatically drives a USSD session.
class UssdBuilder {
  UssdBuilder._();

  static const _momoRoot = '*182';

  /// Send money to another MoMo number: *182*1*1*<phone>*<amount>#
  static String sendMoney({required String phoneNumber, required int amountRwf}) {
    return '$_momoRoot*1*1*$phoneNumber*$amountRwf#';
  }

  /// Pay a merchant/till code: *182*8*1*<code>*<amount>#
  static String payMerchant({required String tillCode, required int amountRwf}) {
    return '$_momoRoot*8*1*$tillCode*$amountRwf#';
  }

  /// Buy airtime for own line: *182*2*1*<amount>#
  static String buyAirtime({required int amountRwf}) {
    return '$_momoRoot*2*1*$amountRwf#';
  }

  /// Check MoMo balance: *182*6*1#
  static String checkBalance() => '$_momoRoot*6*1#';
}
