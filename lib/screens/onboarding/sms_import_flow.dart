import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/database.dart';
import '../../menyacash_loader.dart';
import '../../profile/user_profile_service.dart';
import '../../providers/provider_selection_service.dart';
import '../../sms/sms_ingest_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_assets.dart';
import '../../theme/theme_controller.dart';
import '../setup/app_lock_setup_screen.dart';
import 'onboarding_progress.dart';

/// Onboarding steps 3–5: SMS access → Android prompt → Scanning → All
/// set. One widget because the same run is reused from Home's setup
/// checklist ("Import your SMS history") when onboarding's "Not now"
/// skipped it. Back works only on the access step; scanning can't be
/// left mid-way.
///
/// Everything here is on-device: the scan reads the local SMS inbox and
/// writes to the local database. There is no network permission.
class SmsImportFlow extends StatefulWidget {
  const SmsImportFlow({
    super.key,
    required this.ingestService,
    required this.profileService,
    required this.providerSelectionService,
    required this.themeController,
    required this.onFinished,
    required this.onNotNow,
    this.onBack,
    this.inOnboarding = true,
  });

  final SmsIngestService ingestService;
  final UserProfileService profileService;
  final ProviderSelectionService providerSelectionService;
  final ThemeController themeController;

  /// "Go to my dashboard" on the All set screen.
  final VoidCallback onFinished;

  /// "Not now" on the access screen: continue without SMS.
  final VoidCallback onNotNow;
  final VoidCallback? onBack;

  /// Shows the onboarding progress bar; false when pushed from Home.
  final bool inOnboarding;

  @override
  State<SmsImportFlow> createState() => _SmsImportFlowState();
}

enum _Stage { access, requesting, denied, permanentlyDenied, scanning, done }

class _SmsImportFlowState extends State<SmsImportFlow> {
  _Stage _stage = _Stage.access;
  ScanProgress? _progress;
  List<FinancialProvider> _providers = const [];
  DateTime? _earliest;

  @override
  void initState() {
    super.initState();
    widget.providerSelectionService.selectedProviders().then((providers) {
      if (mounted) setState(() => _providers = providers);
    });
  }

  Future<void> _requestAndScan() async {
    setState(() => _stage = _Stage.requesting);

    final status = await widget.ingestService.requestPermissions();
    if (!mounted) return;
    if (!status.isGranted) {
      // A permanently-denied status means Android won't show the dialog
      // again at all — that memory survives uninstall. The only real
      // recovery path is Android's own app-settings screen.
      setState(() {
        _stage = status.isPermanentlyDenied ? _Stage.permanentlyDenied : _Stage.denied;
      });
      return;
    }

    setState(() => _stage = _Stage.scanning);
    await for (final progress in widget.ingestService.scanHistoricalInbox()) {
      if (!mounted) return;
      setState(() => _progress = progress);
    }
    widget.ingestService.startLiveListener();

    final earliest = await widget.ingestService.earliestTransactionAt();
    if (!mounted) return;
    setState(() {
      _earliest = earliest;
      _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _stage == _Stage.access || _stage == _Stage.denied;
    return PopScope(
      // No back during the scan (or once it's done — the only way on is
      // forward); otherwise defer to the onboarding flow's own back.
      canPop: canGoBack && widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoBack) widget.onBack?.call();
      },
      child: Scaffold(
        appBar: widget.inOnboarding || !canGoBack ? null : AppBar(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: switch (_stage) {
              _Stage.access => _AccessStep(
                  providers: _providers,
                  inOnboarding: widget.inOnboarding,
                  onBack: widget.onBack,
                  onAllow: _requestAndScan,
                  onNotNow: widget.onNotNow,
                ),
              _Stage.requesting => const Center(child: MenyaLoader(size: 72)),
              _Stage.denied => _DeniedStep(
                  onRetry: _requestAndScan,
                  onNotNow: widget.onNotNow,
                ),
              _Stage.permanentlyDenied => _PermanentlyDeniedStep(
                  onRetry: _requestAndScan,
                  onNotNow: widget.onNotNow,
                ),
              _Stage.scanning => _ScanningStep(
                  progress: _progress,
                  profileService: widget.profileService,
                  themeController: widget.themeController,
                ),
              _Stage.done => _AllSetStep(
                  progress: _progress,
                  providers: _providers,
                  earliest: _earliest,
                  onFinished: widget.onFinished,
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 · SMS access

class _AccessStep extends StatelessWidget {
  const _AccessStep({
    required this.providers,
    required this.inOnboarding,
    required this.onBack,
    required this.onAllow,
    required this.onNotNow,
  });

  final List<FinancialProvider> providers;
  final bool inOnboarding;
  final VoidCallback? onBack;
  final VoidCallback onAllow;
  final VoidCallback onNotNow;

  /// "MTN MoMo and Bank of Kigali" / "MTN MoMo, eKash and Bank of Kigali".
  String get _providerList {
    final names = providers.map((p) => p.displayName).toList();
    if (names.isEmpty) return 'your providers';
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final body = Theme.of(context).textTheme.bodyMedium;
    final bold = body?.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inOnboarding) OnboardingProgressHeader(step: 2, onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.sms_outlined, color: scheme.primary),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.more_horiz, color: scheme.primary),
                  ),
                  Image.asset('assets/images/menyacash_icon.png', height: 48),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Allow SMS access',
                style: onboardingTitleStyle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This is how Menya Kash finds your transactions. Here’s what happens:',
                style: body?.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const _NumberedStep(n: 1, child: Text('Android asks you to allow SMS access.')),
                    const SizedBox(height: 14),
                    _NumberedStep(
                      n: 2,
                      child: Text.rich(TextSpan(style: body, children: [
                        const TextSpan(text: 'We read past messages from '),
                        TextSpan(text: _providerList, style: bold),
                        const TextSpan(text: ' once to build your history.'),
                      ])),
                    ),
                    const SizedBox(height: 14),
                    const _NumberedStep(
                      n: 3,
                      child: Text('New transactions are added automatically.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const OfflineBanner(
                text: 'Everything stays on this phone. No server, no internet permission.',
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: onAllow,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Allow SMS access'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: onNotNow, child: const Text('Not now')),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.n, required this.child});

  final int n;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeniedStep extends StatelessWidget {
  const _DeniedStep({required this.onRetry, required this.onNotNow});

  final VoidCallback onRetry;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.sms_failed_outlined,
      title: 'SMS access wasn’t allowed',
      body: 'Menya Kash can’t find your transactions without it. You can try '
          'again now, or later from the checklist on Home.',
      primary: FilledButton(onPressed: onRetry, child: const Text('Try again')),
      secondary: TextButton(onPressed: onNotNow, child: const Text('Not now')),
    );
  }
}

/// Android has permanently denied SMS for this app — that decision is
/// keyed by package + signing certificate and survives uninstall, so
/// [Permission.sms.request] will never show a dialog again. The only
/// recovery path is the app's settings page, opened via [openAppSettings].
class _PermanentlyDeniedStep extends StatelessWidget {
  const _PermanentlyDeniedStep({required this.onRetry, required this.onNotNow});

  final VoidCallback onRetry;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.settings_outlined,
      title: 'Turn on SMS in Settings',
      body: 'Android remembers this being denied before, even across an '
          'uninstall, so it won’t ask again here. Open Menya Kash’s '
          'settings, allow SMS, then come back.',
      primary: FilledButton.icon(
        onPressed: () => openAppSettings(),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Open app settings'),
      ),
      secondary: Column(
        children: [
          TextButton(onPressed: onRetry, child: const Text('I’ve allowed it, check again')),
          TextButton(onPressed: onNotNow, child: const Text('Not now')),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget primary;
  final Widget secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        primary,
        const SizedBox(height: 4),
        secondary,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4 · Scanning

class _ScanningStep extends StatelessWidget {
  const _ScanningStep({
    required this.progress,
    required this.profileService,
    required this.themeController,
  });

  final ScanProgress? progress;
  final UserProfileService profileService;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final p = progress;
    final count = NumberFormat.decimalPattern();
    final percent = p == null ? 0 : (p.fraction * 100).floor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: p?.fraction,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    const MenyaLoader(size: 110, semanticsLabel: 'Scanning messages'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$percent%',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Reading your messages',
                style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                p == null
                    ? 'Opening your inbox…'
                    : '${count.format(p.processedMessages)} of ${count.format(p.totalMessages)} checked',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted),
              ),
              if (p != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check,
                          size: 14, color: AppBrand.income(Theme.of(context).brightness)),
                      const SizedBox(width: 6),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: count.format(p.matchedTransactions),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text:
                                ' transaction${p.matchedTransactions == 1 ? '' : 's'} found so far',
                          ),
                        ]),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        _WhileYouWait(profileService: profileService, themeController: themeController),
      ],
    );
  }
}

/// Two optional settings to fill the wait — App Lock and theme — so
/// neither needs its own onboarding step.
class _WhileYouWait extends StatefulWidget {
  const _WhileYouWait({required this.profileService, required this.themeController});

  final UserProfileService profileService;
  final ThemeController themeController;

  @override
  State<_WhileYouWait> createState() => _WhileYouWaitState();
}

class _WhileYouWaitState extends State<_WhileYouWait> {
  final _localAuth = LocalAuthentication();
  bool _lockOn = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    widget.profileService.currentProfile().then((p) {
      if (mounted) setState(() => _lockOn = p?.appLockEnabled ?? false);
    });
  }

  Future<void> _turnOnLock() async {
    setState(() => _checking = true);
    final error = await confirmDeviceLock(_localAuth);
    if (error == null) await widget.profileService.setAppLockEnabled(true);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lockOn = error == null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'WHILE YOU WAIT',
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.fingerprint, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turn on App Lock',
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      'Fingerprint, face or PIN',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_lockOn)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 18, color: AppBrand.income(Theme.of(context).brightness)),
                    const SizedBox(width: 4),
                    Text('On', style: text.labelLarge),
                  ],
                )
              else
                FilledButton(
                  onPressed: _checking ? null : _turnOnLock,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Turn on'),
                ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Text('Theme', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => widget.themeController.setMode(s.first),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5 · All set

class _AllSetStep extends StatelessWidget {
  const _AllSetStep({
    required this.progress,
    required this.providers,
    required this.earliest,
    required this.onFinished,
  });

  final ScanProgress? progress;
  final List<FinancialProvider> providers;
  final DateTime? earliest;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final green = AppBrand.income(Theme.of(context).brightness);
    final text = Theme.of(context).textTheme;
    final total = progress?.matchedTransactions ?? 0;
    final byProvider = progress?.matchedByProvider ?? const <String, int>{};
    final count = NumberFormat.decimalPattern();
    final bold = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 32, bottom: 16),
            children: [
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(value: 1, strokeWidth: 5, color: green),
                      ),
                      Image.asset('assets/images/menyacash_icon.png', height: 86),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: green,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 3),
                          ),
                          child: Icon(Icons.check, size: 18, color: scheme.surface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You’re all set',
                style: onboardingTitleStyle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: text.bodyMedium?.copyWith(color: muted),
                  children: total == 0
                      ? const [
                          TextSpan(
                            text: 'No transactions in your inbox yet. They’ll appear '
                                'as soon as a MoMo or bank SMS arrives.',
                          ),
                        ]
                      : [
                          const TextSpan(text: 'We found '),
                          TextSpan(text: count.format(total), style: bold),
                          TextSpan(text: ' transaction${total == 1 ? '' : 's'}'),
                          if (earliest != null) ...[
                            const TextSpan(text: ' going back to '),
                            TextSpan(text: DateFormat.yMMMM().format(earliest!), style: bold),
                          ],
                          const TextSpan(text: '.'),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
              if (providers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      for (final (i, provider) in providers.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              ProviderLogo(
                                providerCode: provider.code,
                                displayName: provider.displayName,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  provider.displayName,
                                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${count.format(byProvider[provider.displayName] ?? 0)} found',
                                style: text.bodySmall?.copyWith(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'New transactions will appear on their own when the SMS arrives.',
                style: text.bodySmall?.copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: onFinished,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Go to my dashboard'),
          ),
        ),
      ],
    );
  }
}
