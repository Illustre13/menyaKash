/// Outcome of starting verification for an email address.
enum EmailVerificationStart {
  /// A code was delivered to the address — the UI must show the
  /// code-entry step and confirm via
  /// [EmailVerificationService.confirmCode].
  codeSent,

  /// No code round-trip is required — the flow completes immediately
  /// after format validation.
  notRequired,
}

/// Abstraction over email-address verification during Account Setup
/// (sprint #5). The onboarding UI is written against this interface
/// only, so swapping in real delivery later (Gmail SMTP credentials
/// are planned) is a one-line substitution at the composition root —
/// the code-entry UI branch already exists and activates the moment an
/// implementation returns [EmailVerificationStart.codeSent].
///
/// The previous interim behavior (generating a code and DISPLAYING it
/// on this same screen) is gone — a code the user copies from the
/// screen verifies nothing and its removal is exactly what this
/// abstraction is for.
abstract class EmailVerificationService {
  /// Begins verification for [email] (already format-validated by the
  /// caller). Implementations that deliver a real code return
  /// [EmailVerificationStart.codeSent].
  Future<EmailVerificationStart> startVerification(String email);

  /// Confirms a delivered code. Only meaningful after
  /// [EmailVerificationStart.codeSent].
  Future<bool> confirmCode({required String email, required String code});
}

/// The current build's implementation: this app has no network
/// permission and therefore no delivery channel, so verification is
/// not required — the address is stored after format validation, and
/// no fake code ceremony is performed. Replaced wholesale once real
/// SMTP delivery is configured.
class LocalNoDeliveryEmailVerification implements EmailVerificationService {
  const LocalNoDeliveryEmailVerification();

  @override
  Future<EmailVerificationStart> startVerification(String email) async =>
      EmailVerificationStart.notRequired;

  @override
  Future<bool> confirmCode({required String email, required String code}) async => false;
}
