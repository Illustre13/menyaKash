import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/database.dart';
import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import '../../sms/sms_ingest_service.dart';
import '../../theme/provider_assets.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/coming_soon_popup.dart';
import 'provider_backfill_popup.dart';

/// Settings (spec Phase 7, extended in the UI sprint): Appearance,
/// Security, Financial Providers, and Data sections, reached from the
/// Profile screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.profileService,
    required this.providerSelectionService,
    this.smsIngestService,
  });

  final UserProfileService profileService;
  final ProviderSelectionService providerSelectionService;

  /// Null on the web dev-preview entry point — see [ProfileScreen]'s
  /// same field for why enabling a provider needs this.
  final SmsIngestService? smsIngestService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localAuth = LocalAuthentication();
  late final _themeController = ThemeController(widget.profileService);

  UserProfileData? _profile;
  List<ProviderSelectionOption>? _providerOptions;

  Future<void> _setTheme(ThemeMode mode) async {
    await _themeController.setMode(mode);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.profileService.currentProfile();
    final options = await widget.providerSelectionService.allProviderOptions();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _providerOptions = options;
    });
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (!enabled) {
      await widget.profileService.setAppLockEnabled(false);
      await _load();
      return;
    }

    final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canCheck) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fingerprint, face, PIN, or pattern lock is set up.')),
      );
      return;
    }

    final confirmed = await _localAuth.authenticate(
      localizedReason: 'Confirm to enable App Lock for Menya Kash',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (confirmed) {
      await widget.profileService.setAppLockEnabled(true);
    }
    await _load();
  }

  Future<void> _toggleProvider(int providerId, bool selected, String displayName) async {
    if (selected) {
      await widget.providerSelectionService.selectProviders([providerId]);
      await _load();
      // Confirmed real gap (review batch item #1): selectProviders only
      // creates the Accounts row — without this, a provider enabled
      // after onboarding sits at "Balance unknown" until a fresh SMS
      // happens to arrive, even though its whole history is already
      // sitting in the phone's inbox. Only runs on enable, and only
      // when this isn't the web dev-preview build (no real SMS inbox
      // there).
      final ingestService = widget.smsIngestService;
      if (ingestService != null && mounted) {
        await showProviderBackfillPopup(
          context,
          providerDisplayName: displayName,
          smsIngestService: ingestService,
        );
      }
    } else {
      await widget.providerSelectionService.deselectProvider(providerId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final providerOptions = _providerOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: (profile == null || providerOptions == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('Appearance'),
                RadioGroup<ThemeMode>(
                  groupValue: ThemeController.mode.value,
                  onChanged: (mode) => _setTheme(mode!),
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: Text('Light'),
                        value: ThemeMode.light,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text('Dark'),
                        value: ThemeMode.dark,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text('System'),
                        subtitle: Text('Follow your phone\'s setting'),
                        value: ThemeMode.system,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                const _SectionHeader('Security'),
                SwitchListTile(
                  title: const Text('App Lock'),
                  subtitle: const Text('Require fingerprint, face, PIN, or pattern to open Menya Kash'),
                  value: profile.appLockEnabled,
                  onChanged: _toggleAppLock,
                ),
                ListTile(
                  title: const Text('Change Authentication'),
                  subtitle: const Text('Re-check your device\'s lock screen'),
                  onTap: () => _toggleAppLock(true),
                ),
                const Divider(),
                const _SectionHeader('Financial Providers'),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Connected Services'),
                ),
                ...providerOptions.map((option) => SwitchListTile(
                      secondary: ProviderLogo(
                        providerCode: option.provider.code,
                        displayName: option.provider.displayName,
                        size: 36,
                      ),
                      title: Text(option.provider.displayName),
                      value: option.isSelected,
                      onChanged: (value) =>
                          _toggleProvider(option.provider.id, value, option.provider.displayName),
                    )),
                const Divider(),
                const _SectionHeader('Data'),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Export Statement'),
                  subtitle: const Text('Save your transaction history to this device'),
                  onTap: () => showComingSoonPopup(
                    context,
                    feature: 'Export Statement',
                    icon: Icons.description_outlined,
                    description: 'Download your transaction history as PDF, Excel, or CSV.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Backup SMS'),
                  subtitle: const Text('Save your raw SMS evidence to this device'),
                  onTap: () => showComingSoonPopup(
                    context,
                    feature: 'Backup SMS',
                    icon: Icons.sms_outlined,
                    description:
                        'Save a copy of your raw SMS evidence to this device, independent of your transaction history.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.save_outlined),
                  title: const Text('Local Backup'),
                  subtitle: const Text('Export or restore a backup file — never sent over a network'),
                  onTap: () => showComingSoonPopup(
                    context,
                    feature: 'Local Backup',
                    icon: Icons.save_outlined,
                    description:
                        'Export or restore a full backup file, still entirely on this device.',
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
