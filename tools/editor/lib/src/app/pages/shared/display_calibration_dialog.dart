import 'dart:async';

import 'package:flutter/material.dart';

import '../../../playtest/display_calibration.dart';

/// Owns just the calibration route so source replacement or leaving Play also
/// dismisses its child modal, without popping unrelated editor routes.
final class DisplayCalibrationFlow {
  DialogRoute<bool>? _route;
  bool _disposed = false;

  Future<bool> open(
    BuildContext context, {
    required EditorDisplayReader reader,
    required DisplayCalibrationStore store,
  }) async {
    if (_disposed || _route != null) return false;
    await store.load();
    if (_disposed || !context.mounted || _route != null) return false;
    final route = DialogRoute<bool>(
      context: context,
      builder: (_) => DisplayCalibrationDialog(reader: reader, store: store),
    );
    _route = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push(route) ??
          false;
    } finally {
      if (identical(_route, route)) _route = null;
    }
  }

  void dispose() {
    _disposed = true;
    final route = _route;
    _route = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}

/// A ruler measurement is the source of scale; OS DPI is only a conversion.
class DisplayCalibrationDialog extends StatefulWidget {
  const DisplayCalibrationDialog({
    super.key,
    required this.reader,
    required this.store,
  });
  final EditorDisplayReader reader;
  final DisplayCalibrationStore store;
  @override
  State<DisplayCalibrationDialog> createState() =>
      _DisplayCalibrationDialogState();
}

class _DisplayCalibrationDialogState extends State<DisplayCalibrationDialog> {
  final _referenceKey = GlobalKey();
  final _referenceViewportKey = GlobalKey();
  final _measurement = TextEditingController();
  final _length = TextEditingController(text: '400');
  double _referencePixels = 400;
  EditorMonitor? _monitor;
  EditorDisplayEnvironment? _environment;
  String? _error;
  bool _busy = false;
  Future<void>? _reading;
  double? _referenceDpr;
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) => _read());
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  Future<void> _read() =>
      _reading ??= _readEnvironment().whenComplete(() => _reading = null);

  Future<void> _readEnvironment() async {
    if (_busy) return;
    final environment = await widget.reader.read();
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final box = _referenceKey.currentContext?.findRenderObject();
    final viewport = _referenceViewportKey.currentContext?.findRenderObject();
    final fits =
        box is RenderBox &&
        viewport is RenderBox &&
        box.hasSize &&
        viewport.hasSize &&
        box.size.width <= viewport.size.width;
    final monitor = fits
        ? environment?.containing(
            environment.physicalBounds(
              box.localToGlobal(Offset.zero) & box.size,
              dpr,
            ),
          )
        : null;
    if (monitor?.signature != _monitor?.signature ||
        environment?.remote != _environment?.remote ||
        dpr != _referenceDpr) {
      setState(() {
        _measurement.clear();
        _referenceDpr = dpr;
        _monitor = monitor;
        _environment = environment;
      });
    }
  }

  Future<void> _save({DisplayCalibration? reuse}) async {
    await _read();
    if (!mounted) return;
    final monitor = _monitor;
    final mm = double.tryParse(_measurement.text.trim());
    if (monitor == null ||
        (reuse == null &&
            (mm == null || !mm.isFinite || mm < 20 || mm > 500))) {
      setState(
        () => _error = 'Keep the entire line visible on one monitor and enter its measured length (20–500 mm). Shorten the reference or enlarge the window if it is clipped.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (reuse != null) {
        widget.store.confirm(monitor, reuse);
      } else {
        await widget.store.save(
          DisplayCalibration(
            signature: monitor.signature,
            pixelsPerMm:
                _referencePixels * MediaQuery.devicePixelRatioOf(context) / mm!,
            label:
                '${monitor.name} · ${monitor.bounds.width.toInt()}×${monitor.bounds.height.toInt()}',
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Calibration could not be saved: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _measurement.dispose();
    _length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Calibrate this monitor'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Measure the line between its end marks with a real ruler. Enter the measured length below. For best accuracy use at least 100 mm.',
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              key: _referenceViewportKey,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                key: _referenceKey,
                width: _referencePixels,
                height: 24,
                child: CustomPaint(
                  painter: _ReferenceLine(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _length,
              decoration: const InputDecoration(
                labelText: 'Reference length (editor pixels, 100–1000)',
              ),
              keyboardType: TextInputType.number,
              onChanged: (text) {
                final value = double.tryParse(text);
                if (value != null &&
                    value.isFinite &&
                    value >= 100 &&
                    value <= 1000) {
                  setState(() {
                    _referencePixels = value;
                    _measurement.clear();
                    _monitor = null;
                  });
                }
              },
            ),
            TextField(
              key: const ValueKey('calibration_measured_mm'),
              controller: _measurement,
              decoration: const InputDecoration(
                labelText: 'Measured length (mm)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _monitor == null
                  ? 'Waiting for a reference entirely inside one monitor. Native Windows display support is required.'
                  : 'Monitor: ${_monitor!.name}${_environment?.remote == true ? ' · remote session: verify with your ruler' : ''}',
            ),
            if (_monitor != null &&
                (_environment?.remote == true || !_monitor!.identified) &&
                widget.store.profiles.isNotEmpty)
              DropdownButtonFormField<DisplayCalibration>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Or select a profile you have verified here',
                ),
                items: [
                  for (final profile in widget.store.profiles)
                    DropdownMenuItem(
                      value: profile,
                      child: Text(profile.label),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (profile) {
                        if (profile != null) _save(reuse: profile);
                      },
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('calibration_save'),
        onPressed: _busy ? null : () => _save(),
        child: const Text('Use calibration'),
      ),
    ],
  );
}

class _ReferenceLine extends CustomPainter {
  const _ReferenceLine(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReferenceLine oldDelegate) =>
      color != oldDelegate.color;
}
