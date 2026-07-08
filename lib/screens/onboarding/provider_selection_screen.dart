import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../providers/provider_selection_service.dart';

/// Onboarding step 5 (spec Phase 6, Screen 4): the user explicitly
/// selects which financial providers they use, grouped as "Mobile
/// Money" and "Banks". This selection is the real gate for which
/// [Accounts] rows exist from schemaVersion 4 onward — see
/// [ProviderSelectionService] and [UserFinancialSources].
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
    });
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    await widget.service.selectProviders(_selected.toList());
    if (!mounted) return;
    widget.onContinue();
  }

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
                          'Which of these do you use? You can add or remove '
                          'providers later in Settings.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        _ProviderGroup(
                          title: 'Mobile Money',
                          options: options.where((o) => o.provider.category == 'mobile_money'),
                          selected: _selected,
                          onToggle: (id, value) => setState(() {
                            if (value) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                        ),
                        const SizedBox(height: 16),
                        _ProviderGroup(
                          title: 'Banks',
                          options: options.where((o) => o.provider.category == 'bank'),
                          selected: _selected,
                          onToggle: (id, value) => setState(() {
                            if (value) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                        ),
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
}

class _ProviderGroup extends StatelessWidget {
  const _ProviderGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final Iterable<ProviderSelectionOption> options;
  final Set<int> selected;
  final void Function(int providerId, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final list = options.toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((option) {
            final isSelected = selected.contains(option.provider.id);
            return FilterChip(
              label: Text(option.provider.displayName),
              selected: isSelected,
              onSelected: (value) => onToggle(option.provider.id, value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
