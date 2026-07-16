import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../accounts/accounts_service.dart';
import '../../data/database.dart';
import '../../premium/premium_popup.dart';
import '../../profile/referral_service.dart';
import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import '../../theme/provider_assets.dart';
import 'referral_screen.dart';
import 'settings_screen.dart';

/// Profile screen (spec Phase 7): identity, security shortcut, and
/// connected accounts. No Subscription row in the billing sense — there
/// is no IAP system in this offline app — but an "Upgrade to Premium"
/// entry point does live here (spec #5), opening a popup that's honest
/// about what's real (free today) vs. planned (coming soon, no price).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.accountsService,
    required this.providerSelectionService,
    required this.referralService,
  });

  final UserProfileService profileService;
  final AccountsService accountsService;
  final ProviderSelectionService providerSelectionService;
  final ReferralService referralService;

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

  void _openReferral() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReferralScreen(referralService: widget.referralService),
      ),
    );
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
                Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => showPremiumPopup(context),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium_outlined,
                              color: Theme.of(context).colorScheme.onPrimaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Upgrade to Premium',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard_outlined),
                    title: const Text('Refer a friend'),
                    subtitle: const Text('Share your code'),
                    onTap: _openReferral,
                    trailing: const Icon(Icons.chevron_right),
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
                                  leading: ProviderLogo(
                                    providerCode: summary.providerCode,
                                    displayName: summary.providerDisplayName,
                                    size: 36,
                                  ),
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
