import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/database.dart';
import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';

/// Settings (spec Phase 7): Security, Financial Providers, and Data
/// sections, reached from the Profile screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.profileService,
    required this.providerSelectionService,
  });

  final UserProfileService profileService;
  final ProviderSelectionService providerSelectionService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localAuth = LocalAuthentication();

  UserProfileData? _profile;
  List<ProviderSelectionOption>? _providerOptions;

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
      localizedReason: 'Confirm to enable App Lock for i-momo',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (confirmed) {
      await widget.profileService.setAppLockEnabled(true);
    }
    await _load();
  }

  Future<void> _toggleProvider(int providerId, bool selected) async {
    if (selected) {
      await widget.providerSelectionService.selectProviders([providerId]);
    } else {
      await widget.providerSelectionService.deselectProvider(providerId);
    }
    await _load();
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
                const _SectionHeader('Security'),
                SwitchListTile(
                  title: const Text('App Lock'),
                  subtitle: const Text('Require fingerprint, face, PIN, or pattern to open i-momo'),
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
                      title: Text(option.provider.displayName),
                      value: option.isSelected,
                      onChanged: (value) => _toggleProvider(option.provider.id, value),
                    )),
                const Divider(),
                const _SectionHeader('Data'),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Export Statement'),
                  subtitle: const Text('Save your transaction history to this device'),
                  onTap: () => _notImplementedYet(context, 'Export Statement'),
                ),
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Backup SMS'),
                  subtitle: const Text('Save your raw SMS evidence to this device'),
                  onTap: () => _notImplementedYet(context, 'Backup SMS'),
                ),
                ListTile(
                  leading: const Icon(Icons.save_outlined),
                  title: const Text('Local Backup'),
                  subtitle: const Text('Export or restore a backup file — never sent over a network'),
                  onTap: () => _notImplementedYet(context, 'Local Backup'),
                ),
              ],
            ),
    );
  }

  void _notImplementedYet(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
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
