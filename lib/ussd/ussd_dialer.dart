import 'package:url_launcher/url_launcher.dart';

/// Hands a USSD string off to the native dialer for the user to confirm
/// and send. Deliberately does NOT place the call or read the response —
/// that would require an Accessibility Service, which this app does not
/// use. `tel:` triggers the dialer (pre-filled), not a silent call, so no
/// CALL_PHONE runtime permission prompt is needed for this flow.
class UssdDialer {
  UssdDialer._();

  static Future<bool> dial(String ussdCode) async {
    // '#' must stay literal for USSD; url_launcher/Android handles this
    // correctly via the tel: scheme without percent-encoding it away.
    final uri = Uri(scheme: 'tel', path: ussdCode);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }
}
