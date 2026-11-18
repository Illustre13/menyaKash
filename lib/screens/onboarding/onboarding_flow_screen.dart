import 'package:flutter/material.dart';

import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import '../../sms/sms_ingest_service.dart';
import '../../theme/theme_controller.dart';
import 'provider_selection_screen.dart';
import 'sms_import_flow.dart';
import 'welcome_screen.dart';

/// Top-level onboarding controller — 5 steps: Welcome + terms →
/// Providers → SMS access → (Android prompt) → Scanning → All set.
/// Steps 3–5 live in [SmsImportFlow].
///
/// Everything else that used to be an onboarding step moved out of the
/// way of a first launch: App Lock and email are on Home's "Finish
/// setting up" checklist (plus a one-off App Lock reminder), the theme
/// defaults to Auto and lives in Settings → Appearance (it can also be
/// changed on the scanning screen while waiting).
///
/// SMS "Not now" still completes onboarding: Home opens on its empty
/// state with "Import your SMS history" on the checklist. Back works on
/// steps 2–3; not during the scan.
///
/// Each step writes its own result as the user completes it, so a user
/// who force-quits mid-flow doesn't lose earlier steps. Only
/// [UserProfileService.markOnboardingComplete] is deferred to the very
/// end, since that flag is what decides whether onboarding shows at all.
class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({
    super.key,
    required this.ingestService,
    required this.profileService,
    required this.providerSelectionService,
    required this.themeController,
    required this.onComplete,
  });

  final SmsIngestService ingestService;
  final UserProfileService profileService;
  final ProviderSelectionService providerSelectionService;
  final ThemeController themeController;
  final VoidCallback onComplete;

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

enum _Step { welcome, providers, sms }

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  _Step _step = _Step.welcome;

  void _goTo(_Step step) => setState(() => _step = step);

  Future<void> _finish() async {
    await widget.profileService.markOnboardingComplete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _Step.welcome => WelcomeScreen(onContinue: () => _goTo(_Step.providers)),
      _Step.providers => ProviderSelectionScreen(
          service: widget.providerSelectionService,
          onContinue: () => _goTo(_Step.sms),
          onBack: () => _goTo(_Step.welcome),
        ),
      _Step.sms => SmsImportFlow(
          ingestService: widget.ingestService,
          profileService: widget.profileService,
          providerSelectionService: widget.providerSelectionService,
          themeController: widget.themeController,
          onBack: () => _goTo(_Step.providers),
          onNotNow: _finish,
          onFinished: _finish,
        ),
    };
    // Android back on Providers goes to Welcome; SmsImportFlow handles
    // its own (back on access, blocked during the scan).
    if (_step != _Step.providers) return page;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(_Step.welcome);
      },
      child: page,
    );
  }
}
