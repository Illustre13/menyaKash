import 'package:flutter/material.dart';

import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import '../../sms/sms_ingest_service.dart';
import '../../theme/theme_controller.dart';
import 'account_setup_screen.dart';
import 'permission_summary_screen.dart';
import 'provider_selection_screen.dart';
import 'security_setup_screen.dart';
import 'sms_setup_screen.dart';
import 'terms_screen.dart';
import 'theme_choice_screen.dart';
import 'welcome_screen.dart';

/// Top-level onboarding controller (spec Phases 5 + 6, extended by the
/// UI sprint): Welcome → Appearance → Terms & Privacy → Account Setup →
/// Security Setup → Provider Selection → Permission Summary → SMS
/// Setup. The permission summary sits immediately before the first OS
/// permission dialog (sprint #9) so nothing the system asks is a
/// surprise; the theme choice sits right after Welcome (sprint #3) so
/// the rest of onboarding is already rendered in the user's chosen
/// look.
///
/// Each step writes its own result to the services as the user
/// completes it, rather than threading state through every screen and
/// writing once at the end — so a user who force-quits mid-flow doesn't
/// lose earlier steps on next launch. Only
/// [UserProfileService.markOnboardingComplete] is deferred to the very
/// end, since that flag is what determines whether onboarding shows at
/// all.
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

enum _Step { welcome, theme, terms, account, security, providers, permissions, sms }

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  _Step _step = _Step.welcome;

  void _goTo(_Step step) => setState(() => _step = step);

  Future<void> _onThemeSelected(ThemeMode mode) async {
    // Applies live (the app re-themes under this screen) and persists.
    await widget.themeController.setMode(mode);
    if (mounted) setState(() {});
  }

  Future<void> _onAccountSetupContinue(String email) async {
    await widget.profileService.updateProfile(email: email);
    _goTo(_Step.security);
  }

  Future<void> _onSecuritySetupContinue(bool appLockEnabled) async {
    await widget.profileService.setAppLockEnabled(appLockEnabled);
    _goTo(_Step.providers);
  }

  Future<void> _onSmsSetupComplete() async {
    await widget.profileService.markOnboardingComplete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.welcome => WelcomeScreen(onContinue: () => _goTo(_Step.theme)),
      _Step.theme => ThemeChoiceScreen(
          current: ThemeController.mode.value,
          onSelected: _onThemeSelected,
          onContinue: () => _goTo(_Step.terms),
        ),
      _Step.terms => TermsScreen(onContinue: () => _goTo(_Step.account)),
      _Step.account => AccountSetupScreen(
          onContinue: _onAccountSetupContinue,
          onSkip: () => _goTo(_Step.security),
        ),
      _Step.security => SecuritySetupScreen(onContinue: _onSecuritySetupContinue),
      _Step.providers => ProviderSelectionScreen(
          service: widget.providerSelectionService,
          onContinue: () => _goTo(_Step.permissions),
        ),
      _Step.permissions => PermissionSummaryScreen(onContinue: () => _goTo(_Step.sms)),
      _Step.sms => SmsSetupScreen(
          ingestService: widget.ingestService,
          onComplete: _onSmsSetupComplete,
        ),
    };
  }
}
