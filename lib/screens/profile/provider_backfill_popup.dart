import 'package:flutter/material.dart';

import '../../sms/sms_ingest_service.dart';
import '../../theme/app_theme.dart';

/// Shown right after a provider is enabled in Settings (review batch
/// item #1) — the confirmed real gap where `selectProviders()` created
/// an [Accounts] row but never scanned the phone's existing SMS for
/// that provider, so a newly-enabled provider sat at "Balance unknown"
/// until a fresh message happened to arrive.
///
/// Re-runs [SmsIngestService.scanHistoricalInbox] (already
/// provider-aware and hash-deduped, per that method's own doc) rather
/// than a dedicated "scan just this one provider" method — the
/// dedup-by-hash means already-known messages for every OTHER selected
/// provider are free no-ops, so scoping the query itself to one
/// provider would save nothing meaningful while adding a second code
/// path to keep in sync with the real one.
Future<void> showProviderBackfillPopup(
  BuildContext context, {
  required String providerDisplayName,
  required SmsIngestService smsIngestService,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ProviderBackfillPopup(
      providerDisplayName: providerDisplayName,
      smsIngestService: smsIngestService,
    ),
  );
}

class _ProviderBackfillPopup extends StatefulWidget {
  const _ProviderBackfillPopup({
    required this.providerDisplayName,
    required this.smsIngestService,
  });

  final String providerDisplayName;
  final SmsIngestService smsIngestService;

  @override
  State<_ProviderBackfillPopup> createState() => _ProviderBackfillPopupState();
}

class _ProviderBackfillPopupState extends State<_ProviderBackfillPopup> {
  ScanProgress? _progress;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    await for (final progress in widget.smsIngestService.scanHistoricalInbox()) {
      if (!mounted) return;
      setState(() => _progress = progress);
    }
    if (!mounted) return;
    setState(() => _done = true);
  }

  int get _matchedForThisProvider =>
      _progress?.matchedByProvider[widget.providerDisplayName] ?? 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_done) ...[
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(value: _progress?.fraction),
              ),
              const SizedBox(height: 20),
              Text('Connecting ${widget.providerDisplayName}',
                  style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Searching your existing messages…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (_progress != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Found: $_matchedForThisProvider transactions so far',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ] else ...[
              Icon(Icons.check_circle, size: 48, color: AppBrand.income(Theme.of(context).brightness)),
              const SizedBox(height: 16),
              Text(
                '${widget.providerDisplayName} connected',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '$_matchedForThisProvider transaction${_matchedForThisProvider == 1 ? '' : 's'} imported',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
