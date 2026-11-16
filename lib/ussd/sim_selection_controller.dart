import 'package:flutter/material.dart';

import 'ussd_dialer.dart';

/// Session-scoped SIM choice (review batch item #2: "the other SIM
/// selector... to bypass that" — every direct-dial call site used to
/// either omit `simSlotIndex` entirely, letting Android show its OWN
/// SIM picker mid-flow, or (Pay screen only) keep the choice as local
/// widget state no other screen could see).
///
/// One instance is owned by `HomeShell` for the app's lifetime and
/// threaded down to every screen that can trigger a USSD action. The
/// chosen slot is asked for once — the first time [ensureChosen] runs
/// on a device with 2+ callable SIMs — and reused for every USSD call
/// afterward in the same session, matching this app's existing
/// "ask once, remember it" pattern (e.g. the onboarding theme choice).
/// A single-SIM device never sees a chooser at all: [ensureChosen]
/// resolves immediately with that device's only slot.
class SimSelectionController {
  List<SimOption>? _sims;
  int? _chosenSlot;
  bool _askedThisSession = false;

  /// The current session's chosen slot, or null if there's nothing to
  /// choose (0 or 1 SIMs) or the user hasn't been asked yet.
  int? get chosenSlot => _chosenSlot;

  Future<List<SimOption>> _loadSims() async {
    return _sims ??= await UssdDialer.listSims();
  }

  /// Resolves to the slot every subsequent [UssdDialer.runDirect] call
  /// this session should use. Shows the in-app chooser (not Android's
  /// own) exactly once per session on a multi-SIM device — every later
  /// call returns the remembered choice immediately, no UI shown.
  /// Returns null on a single-SIM/no-SIM device (nothing to choose;
  /// [UssdDialer.runDirect] with a null slot lets Android pick the only
  /// option there is, which is a no-op choice, not Android's picker).
  Future<int?> ensureChosen(BuildContext context) async {
    final sims = await _loadSims();
    if (sims.length < 2) return null;
    if (_askedThisSession) return _chosenSlot;

    _askedThisSession = true;
    if (!context.mounted) return null;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SimChooserSheet(sims: sims),
    );
    _chosenSlot = chosen ?? sims.first.simSlotIndex;
    return _chosenSlot;
  }

  /// Lets the user deliberately switch SIMs mid-session (e.g. a "change
  /// SIM" row in Settings or Pay) — re-shows the chooser and updates the
  /// remembered choice regardless of [ensureChosen]'s once-per-session
  /// rule.
  Future<int?> reselect(BuildContext context) async {
    final sims = await _loadSims();
    if (sims.length < 2) return null;
    if (!context.mounted) return _chosenSlot;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SimChooserSheet(sims: sims, initialSlot: _chosenSlot),
    );
    if (chosen != null) _chosenSlot = chosen;
    _askedThisSession = true;
    return _chosenSlot;
  }
}

class _SimChooserSheet extends StatelessWidget {
  const _SimChooserSheet({required this.sims, this.initialSlot});

  final List<SimOption> sims;
  final int? initialSlot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.sim_card_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Choose a SIM', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'This choice is remembered for the rest of this session.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            RadioGroup<int>(
              groupValue: initialSlot,
              onChanged: (slot) => Navigator.of(context).pop(slot),
              child: Column(
                children: [
                  for (final sim in sims)
                    RadioListTile<int>(value: sim.simSlotIndex, title: Text(sim.label)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
