import 'package:flutter/material.dart';

import 'saved_meter_service.dart';

/// Shown before dialing Electricity/Water (review batch item #3):
/// "before launching USSD, show a Menya Kash form... meter number...
/// save this meter?" Purely a convenience layer over the confirmed
/// real root codes (*720*1# / *182*3*5#) — the meter number is shown
/// here so the user can read/copy it onto the real on-screen USSD
/// prompt, never embedded into the dialed string itself (no confirmed
/// digit sequence for that exists — see UssdBuilder's class doc).
///
/// Returns true if the user chose to continue (and dial), false/null
/// if they cancelled.
Future<bool?> showMeterEntryPopup(
  BuildContext context, {
  required String service,
  required String title,
  required SavedMeterService savedMeterService,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MeterEntryPopup(
      service: service,
      title: title,
      savedMeterService: savedMeterService,
    ),
  );
}

class _MeterEntryPopup extends StatefulWidget {
  const _MeterEntryPopup({
    required this.service,
    required this.title,
    required this.savedMeterService,
  });

  final String service;
  final String title;
  final SavedMeterService savedMeterService;

  @override
  State<_MeterEntryPopup> createState() => _MeterEntryPopupState();
}

class _MeterEntryPopupState extends State<_MeterEntryPopup> {
  final _controller = TextEditingController();
  bool _saveMeter = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await widget.savedMeterService.meterFor(widget.service);
    if (!mounted) return;
    setState(() {
      if (saved != null) _controller.text = saved;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final meter = _controller.text.trim();
    if (meter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a meter number first.')),
      );
      return;
    }
    if (_saveMeter) {
      await widget.savedMeterService.save(widget.service, meter);
    } else {
      await widget.savedMeterService.clear(widget.service);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.speed_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Meter number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll enter this on the real USSD prompt after dialing — '
                  'Menya Kash can\'t pre-fill it into the code itself.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save this meter number'),
                  subtitle: const Text('So you don\'t have to type it again next time'),
                  value: _saveMeter,
                  onChanged: (v) => setState(() => _saveMeter = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _continue,
                  icon: const Icon(Icons.bolt),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Continue'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
