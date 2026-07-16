import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// One callable SIM slot on this device (spec #7's SIM chooser) — a
/// plain mirror of the native `PhoneAccountHandle` list, never the
/// handle itself.
class SimOption {
  const SimOption({required this.simSlotIndex, required this.label});

  final int simSlotIndex;

  /// Carrier name if available, falling back to the account's own
  /// label — either way, never the phone number or any other
  /// identifier this app has no use for reading.
  final String label;
}

/// Hands USSD codes to the platform. Two levels:
///
/// [dial] — opens the native dialer with the code pre-filled; the user
/// presses call themselves. The `#` is percent-encoded explicitly
/// (`%23`): several OEM dialers drop everything at an unencoded `#`,
/// which presented as "the dialer opens but is empty" on a real test
/// device. `canLaunchUrl` is deliberately not consulted first — it
/// false-negatives for tel: on some Android builds; attempting the
/// launch and reporting the real outcome is more reliable.
///
/// [payNow] — actually initiates the USSD session via a platform
/// channel using ACTION_CALL (see MainActivity.kt). Android itself
/// runs the code and shows the network's response dialog. Requires the
/// CALL_PHONE runtime permission (the caller checks it — see
/// PayScreen). This initiates exactly one user-requested code and
/// never reads or automates the USSD session — no Accessibility
/// Service, same boundary as always. Optional [simSlotIndex] (spec #7)
/// picks which SIM the call goes out on for dual-SIM devices — see
/// [listSims].
class UssdDialer {
  UssdDialer._();

  static const _channel = MethodChannel('menyakash/ussd');

  static Uri _telUri(String ussdCode) => Uri.parse('tel:${Uri.encodeComponent(ussdCode)}');

  /// Pre-fills the dialer. Returns false if no dialer could be opened.
  /// Cannot itself pick a SIM (a `tel:` intent handed to the system
  /// dialer always lets Android/the dialer app ask, if it needs to) —
  /// SIM selection only applies to [payNow]'s direct-dial path.
  static Future<bool> dial(String ussdCode) async {
    try {
      return await launchUrl(_telUri(ussdCode));
    } on PlatformException {
      return false;
    }
  }

  /// Initiates the USSD call directly (Android only). Returns false on
  /// any failure — missing permission, no telephony, non-Android
  /// platform — so callers can fall back to [dial].
  static Future<bool> payNow(String ussdCode, {int? simSlotIndex}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('dialUssd', {
        'code': ussdCode,
        if (simSlotIndex != null) 'simSlotIndex': simSlotIndex,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Web dev preview / tests: the channel doesn't exist there.
      return false;
    }
  }

  /// Every callable SIM slot on this device — empty on a single-SIM
  /// phone, on non-Android platforms, or if the READ_PHONE_STATE
  /// permission was denied (fails soft, never throws): the caller
  /// should only show a SIM chooser at all when this returns 2+
  /// options.
  static Future<List<SimOption>> listSims() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('listSims');
      if (raw == null) return const [];
      return raw
          .whereType<Map<Object?, Object?>>()
          .map((entry) => SimOption(
                simSlotIndex: entry['simSlotIndex'] as int,
                label: (entry['carrierName'] as String?) ??
                    (entry['displayName'] as String?) ??
                    'SIM ${(entry['simSlotIndex'] as int) + 1}',
              ))
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
