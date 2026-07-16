import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../profile/referral_service.dart';
import '../../theme/app_theme.dart';

/// Referral screen (spec #6): shows the device's own referral code and
/// a share button. No signup, no reward tracking, no server round-trip
/// — this app has no backend to redeem a code against, so the value is
/// purely "tell a friend," made easy to do.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key, required this.referralService});

  final ReferralService referralService;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _code;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final code = await widget.referralService.currentCode();
    if (!mounted) return;
    setState(() => _code = code);
  }

  String _shareMessage(String code) =>
      'I track my MoMo & bank spending with Menya Kash — everything stays on my '
      'phone, nothing goes to the cloud. Use my code $code when you install it.';

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied')),
    );
  }

  Future<void> _share(String code) async {
    await Share.share(_shareMessage(code));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = _code;

    return Scaffold(
      appBar: AppBar(title: const Text('Refer a friend')),
      body: code == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        Theme.of(context).brightness == Brightness.dark
                            ? AppBrand.purpleDark.withValues(alpha: 0.7)
                            : AppBrand.purpleLight.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.card_giftcard_outlined, size: 40, color: scheme.onPrimary),
                      const SizedBox(height: 12),
                      Text(
                        'Your referral code',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.onPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              code,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => _copyCode(code),
                              icon: Icon(Icons.copy_outlined, color: scheme.onPrimary, size: 20),
                              tooltip: 'Copy code',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _share(code),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share with a friend'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text('How this works', style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Menya Kash has no account system or server, so this code isn\'t '
                          'tracked or redeemed anywhere — it\'s just an easy way to point '
                          'someone to the app. Sharing opens your phone\'s own share sheet; '
                          'nothing is sent by Menya Kash itself.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
