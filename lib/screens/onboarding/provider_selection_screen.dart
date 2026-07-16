import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../providers/provider_selection_service.dart';
import '../../theme/provider_assets.dart';

/// Onboarding Financial Provider Setup (spec Phase 6, redesigned in
/// the UI sprint's #8): branded provider cards grouped as Mobile Money
/// / Banks. MTN MoMo starts selected by default on a fresh install
/// (it's the overwhelmingly common case in Rwanda); everything else is
/// opt-in. This selection is the real gate for which [Accounts] rows
/// exist and which providers' SMS get scanned — see
/// [ProviderSelectionService] and `snapshotSelectedProviders`.
class ProviderSelectionScreen extends StatefulWidget {
  const ProviderSelectionScreen({
    super.key,
    required this.service,
    required this.onContinue,
  });

  final ProviderSelectionService service;
  final VoidCallback onContinue;

  @override
  State<ProviderSelectionScreen> createState() => _ProviderSelectionScreenState();
}

class _ProviderSelectionScreenState extends State<ProviderSelectionScreen> {
  List<ProviderSelectionOption>? _options;
  final Set<int> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final options = await widget.service.allProviderOptions();
    if (!mounted) return;
    setState(() {
      _options = options;
      _selected.addAll(options.where((o) => o.isSelected).map((o) => o.provider.id));
      // Fresh install, nothing chosen yet: pre-select MTN MoMo (sprint
      // #8 default). Returning users keep exactly their saved set.
      if (_selected.isEmpty) {
        final mtn = options.where((o) => o.provider.code == 'mtn_momo_rw');
        if (mtn.isNotEmpty) _selected.add(mtn.first.provider.id);
      }
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    await widget.service.selectProviders(_selected.toList());
    if (!mounted) return;
    widget.onContinue();
  }

  void _toggle(int providerId, bool value) => setState(() {
        if (value) {
          _selected.add(providerId);
        } else {
          _selected.remove(providerId);
        }
      });

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(title: const Text('Select Financial Providers')),
      body: SafeArea(
        child: options == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Which of these do you use? Only messages from '
                          'providers you enable are scanned. You can change '
                          'this anytime in Settings.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        ..._group(context, 'Mobile Money', options, 'mobile_money'),
                        const SizedBox(height: 20),
                        ..._group(context, 'Banks', options, 'bank'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_selected.isEmpty || _saving) ? null : _confirm,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Continue'),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _group(
    BuildContext context,
    String title,
    List<ProviderSelectionOption> options,
    String category,
  ) {
    final entries = options.where((o) => o.provider.category == category).toList();
    if (entries.isEmpty) return const [];
    return [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      for (final option in entries) ...[
        _ProviderCard(
          code: option.provider.code,
          name: option.provider.displayName,
          selected: _selected.contains(option.provider.id),
          onChanged: (value) => _toggle(option.provider.id, value),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.code,
    required this.name,
    required this.selected,
    required this.onChanged,
  });

  final String code;
  final String name;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              ProviderLogo(providerCode: code, displayName: name),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style:
                      Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
