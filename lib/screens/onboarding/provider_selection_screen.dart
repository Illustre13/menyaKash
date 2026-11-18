import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../providers/provider_selection_service.dart';
import '../../theme/provider_assets.dart';
import 'onboarding_progress.dart';

/// Onboarding 2 · Choose providers (spec Phase 6, redesigned in the UI
/// sprint's #8 and again for the 5-step onboarding): compact checkbox
/// rows grouped as Mobile Money / Banks. Also pushed on its own from
/// Home's setup checklist ([inOnboarding] false: app bar, no progress). MTN MoMo starts selected by default on a fresh install
/// (it's the overwhelmingly common case in Rwanda); everything else is
/// opt-in. This selection is the real gate for which [Accounts] rows
/// exist and which providers' SMS get scanned — see
/// [ProviderSelectionService] and `snapshotSelectedProviders`.
class ProviderSelectionScreen extends StatefulWidget {
  const ProviderSelectionScreen({
    super.key,
    required this.service,
    required this.onContinue,
    this.onBack,
    this.inOnboarding = true,
  });

  final ProviderSelectionService service;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final bool inOnboarding;

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
    final scheme = Theme.of(context).colorScheme;
    final count = _selected.length;
    return Scaffold(
      appBar: widget.inOnboarding ? null : AppBar(title: const Text('Your accounts')),
      body: SafeArea(
        child: options == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.inOnboarding)
                      OnboardingProgressHeader(step: 1, onBack: widget.onBack),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 20, bottom: 16),
                        children: [
                          Text('Which accounts do you use?', style: onboardingTitleStyle(context)),
                          const SizedBox(height: 8),
                          Text(
                            'We only read messages from the ones you pick. Change this any time.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          ..._group(context, 'Mobile money', options, 'mobile_money'),
                          const SizedBox(height: 12),
                          ..._group(context, 'Banks', options, 'bank'),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: (count == 0 || _saving) ? null : _confirm,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                count == 0
                                    ? 'Pick at least one'
                                    : 'Continue with $count account${count == 1 ? '' : 's'}',
                              ),
                            ),
                    ),
                  ],
                ),
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
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      for (final option in entries) ...[
        _ProviderCard(
          code: option.provider.code,
          name: option.provider.displayName,
          selected: _selected.contains(option.provider.id),
          onChanged: (value) => _toggle(option.provider.id, value),
        ),
        const SizedBox(height: 8),
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
    return Semantics(
      checked: selected,
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ProviderLogo(providerCode: code, displayName: name, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (v) => onChanged(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
