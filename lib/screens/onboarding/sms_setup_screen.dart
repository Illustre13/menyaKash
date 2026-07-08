import 'package:flutter/material.dart';

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

enum _Stage { explain, requesting, scanning, denied }

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  _Stage _stage = _Stage.explain;
  ScanProgress? _progress;

  Future<void> _startScan() async {
    setState(() => _stage = _Stage.requesting);

    final granted = await widget.ingestService.requestPermissions();
    if (!granted) {
      setState(() => _stage = _Stage.denied);
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
            '${p.matchedTransactions} MoMo transaction'
            '${p.matchedTransactions == 1 ? '' : 's'} found so far',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
          'i-momo can\'t read your MoMo messages without this permission, '
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
