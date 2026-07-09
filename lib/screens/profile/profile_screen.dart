import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../data/database.dart';
import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import 'settings_screen.dart';

/// Profile screen (spec Phase 7): identity, security shortcut, and
/// connected accounts. No Subscription row — there is no billing/IAP
/// system in this offline app, so a fake one isn't built here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.accountsService,
    required this.providerSelectionService,
  });

  final UserProfileService profileService;
  final AccountsService accountsService;
  final ProviderSelectionService providerSelectionService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileData? _profile;
  List<AccountSummary>? _accounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await widget.profileService.currentProfile();
    final accounts = await widget.accountsService.allAccountSummaries();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _accounts = accounts;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          profileService: widget.profileService,
          providerSelectionService: widget.providerSelectionService,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _renameAccount(AccountSummary summary) async {
    final controller = TextEditingController(text: summary.account.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename account'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newLabel == null || newLabel.isEmpty) return;
    await widget.accountsService.renameAccount(summary.account.id, newLabel);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final accounts = _accounts;
    final currency = NumberFormat.currency(symbol: 'RWF ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: (profile == null || accounts == null)
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    profile.displayName ?? 'Your profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(profile.email ?? 'Not set'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: Text(profile.phone ?? 'Not set'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.security_outlined),
                        title: const Text('Security'),
                        subtitle: Text(profile.appLockEnabled ? 'App Lock enabled' : 'App Lock off'),
                        onTap: _openSettings,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Connected Accounts', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: accounts.isEmpty
                        ? [
                            const ListTile(
                              title: Text('No accounts yet'),
                              subtitle: Text('Add a provider from Settings'),
                            ),
                          ]
                        : accounts
                            .map((summary) => ListTile(
                                  title: Text(summary.account.label),
                                  subtitle: Text(summary.providerDisplayName),
                                  trailing: Text(
                                    summary.currentBalance != null
                                        ? currency.format(summary.currentBalance)
                                        : '—',
                                  ),
                                  onTap: () => _renameAccount(summary),
                                ))
                            .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Settings'),
                ),
              ],
            ),
    );
  }
}
