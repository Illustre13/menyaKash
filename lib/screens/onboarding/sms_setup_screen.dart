import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../sms/sms_ingest_service.dart';

/// Onboarding step 6 (spec Phase 5, final step): explains why SMS
/// access is needed (entirely on-device, nothing ever leaves the
/// phone), requests the permission, then shows live progress while
/// every existing MoMo message in the inbox is scanned and classified.
/// Deliberately last in the flow — identity and security setup
/// establish trust before this, the most sensitive permission ask.
class SmsSetupScreen extends StatefulWidget {
  const SmsSetupScreen({
    super.key,
    required this.ingestService,
    required this.onComplete,
  });

  final SmsIngestService ingestService;

  /// Called once the initial scan finishes (or the user is already
  /// permitted from a previous run).
  final VoidCallback onComplete;

  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

enum _Stage { explain, requesting, scanning, denied, permanentlyDenied }

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  _Stage _stage = _Stage.explain;
  ScanProgress? _progress;

  Future<void> _startScan() async {
    setState(() => _stage = _Stage.requesting);

    final status = await widget.ingestService.requestPermissions();
    if (!status.isGranted) {
      // Confirmed real bug (user report: "no SMS feeding process
      // shown," reinstalling didn't help): a permanently-denied status
      // means Android won't show the request dialog again at all — no
      // amount of "Try again" in this app will ever produce one, since
      // that decision lives in Android's own permission memory, keyed
      // by package+signature, which survives uninstall/reinstall. The
      // only real recovery path is Android's own app-settings screen.
      setState(() {
        _stage =
            status.isPermanentlyDenied ? _Stage.permanentlyDenied : _Stage.denied;
      });
      return;
    }

    setState(() => _stage = _Stage.scanning);

    await for (final progress in widget.ingestService.scanHistoricalInbox()) {
      if (!mounted) return;
      setState(() => _progress = progress);
    }

    widget.ingestService.startLiveListener();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: switch (_stage) {
              _Stage.explain => _ExplainStep(onContinue: _startScan),
              _Stage.requesting => const _SimpleStatus(
                  message: 'Requesting SMS permission…',
                ),
              _Stage.scanning => _ScanningStep(progress: _progress),
              _Stage.denied => _DeniedStep(onRetry: _startScan),
              _Stage.permanentlyDenied => _PermanentlyDeniedStep(onRetry: _startScan),
            },
          ),
        ),
      ),
    );
  }
}

class _ExplainStep extends StatelessWidget {
  const _ExplainStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 56),
        const SizedBox(height: 24),
        Text(
          'One last step',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To track your MoMo spending, this app reads mobile money '
          'notification texts from your SMS inbox.\n\n'
          'Everything happens on this device. No message, transaction, '
          'or amount is ever sent anywhere — there is no server and no '
          'internet permission in this app at all.\n\n'
          'On the next screen, Android will ask you to allow SMS access. '
          'We\'ll then scan your existing messages once to bring in your '
          'MoMo history, and quietly watch for new ones after that.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: onContinue,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('Continue'),
          ),
        ),
      ],
    );
  }
}

class _SimpleStatus extends StatelessWidget {
  const _SimpleStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ScanningStep extends StatelessWidget {
  const _ScanningStep({required this.progress});

  final ScanProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(value: p?.fraction),
        ),
        const SizedBox(height: 24),
        Text(
          'Scanning your messages…',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (p != null) ...[
          Text(
            '${p.processedMessages} of ${p.totalMessages} messages checked',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '${p.matchedTransactions} transaction'
            '${p.matchedTransactions == 1 ? '' : 's'} found so far',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // Per-provider breakdown (spec #1): only worth showing once
          // more than one provider is actually selected — with a
          // single provider the total above already says the same
          // thing, so a one-row "breakdown" would be pure noise.
          if (p.matchedByProvider.length > 1) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    for (final entry in p.matchedByProvider.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              '${entry.value}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ] else
          Text(
            'Reading inbox…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _DeniedStep extends StatelessWidget {
  const _DeniedStep({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 16),
        Text(
          'SMS permission is required',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Menya Kash can\'t read your MoMo messages without this permission, '
          'so it has nothing to show you. You can grant it from your '
          'phone\'s app settings, or try again below.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

/// Shown when Android's own permission memory has already permanently
/// denied SMS access for this app (confirmed real bug: "no SMS feeding
/// process shown," reinstalling didn't fix it) — that decision is
/// keyed by package name + signing certificate, lives outside this
/// app's own data, and survives uninstalling and reinstalling the app.
/// [Permission.sms.request] will never show a dialog again once this
/// state is reached; the only real recovery path is Android's own app
/// settings screen, opened directly via [openAppSettings].
class _PermanentlyDeniedStep extends StatelessWidget {
  const _PermanentlyDeniedStep({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.settings_outlined, size: 56),
        const SizedBox(height: 16),
        Text(
          'SMS permission needs to be turned on in Settings',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Android remembers this being denied before — even across an '
          'uninstall — so it won\'t ask again in-app. Open Menya Kash\'s '
          'settings, allow SMS, then come back and continue.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => openAppSettings(),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open app settings'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('I\'ve allowed it — check again')),
      ],
    );
  }
}
