import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';

/// A single phone number entry from the device's contact list, reduced
/// to just what the Pay screen needs. Never persisted — read fresh from
/// the OS contact provider each time, same "no local copy of PII beyond
/// what's needed" posture as the rest of this app.
class ContactOption {
  const ContactOption({required this.displayName, required this.phoneNumber});
  final String displayName;
  final String phoneNumber;
}

/// Thin wrapper around flutter_contacts so the rest of the app depends
/// on a small typed surface, not the plugin directly. Contacts are read
/// on-device only — nothing here ever leaves the phone.
///
/// Every method fails safe (returns false/empty) rather than throwing on
/// a platform with no real contacts support — notably Flutter web, where
/// permission_handler_html throws UnimplementedError for
/// Permission.contacts instead of reporting "denied". This app's real
/// target is Android-only; the web dev preview should degrade to "no
/// contacts available" rather than crash the Pay screen.
class ContactsService {
  Future<bool> hasPermission() async {
    try {
      return await Permission.contacts.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.contacts.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// All contacts that have at least one phone number, flattened to one
  /// entry per number (a contact with two numbers appears twice) so the
  /// picker list is unambiguous about which number will be dialed.
  ///
  /// Returns an empty list rather than throwing on platforms without a
  /// contacts plugin implementation (e.g. the Flutter-web dev preview —
  /// this app's real target is Android-only, but the UI should degrade
  /// to "no contacts" instead of crashing the screen).
  Future<List<ContactOption>> loadContactsWithPhoneNumbers() async {
    List<fc.Contact> contacts;
    try {
      contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    } catch (_) {
      return const [];
    }

    final options = <ContactOption>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;
        options.add(ContactOption(
          displayName: contact.displayName.isEmpty ? number : contact.displayName,
          phoneNumber: number,
        ));
      }
    }
    return options;
  }
}
