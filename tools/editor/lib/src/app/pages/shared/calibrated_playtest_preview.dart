import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';
import 'package:rpg_runner/playtest/runner_playtest_display_frame.dart';

import '../../../playtest/display_calibration.dart';
import '../../../playtest/playtest_device_screen.dart';
import 'display_calibration_dialog.dart';

/// Keeps a live attempt across monitor changes. Invalid geometry pauses and
/// blocks input; resolving it never resumes gameplay on the user's behalf.
class CalibratedPlaytestPreview extends StatefulWidget {
  const CalibratedPlaytestPreview({
    super.key,
    required this.settings,
    required this.controller,
    required this.child,
    this.reader = const NativeEditorDisplayReader(),
    this.store,
  });
  final EditorPlaytestSettings settings;
  final RunnerPlaytestController controller;
  final Widget child;
  final EditorDisplayReader reader;
  final DisplayCalibrationStore? store;
  @override
  State<CalibratedPlaytestPreview> createState() =>
      _CalibratedPlaytestPreviewState();
}

class _CalibratedPlaytestPreviewState extends State<CalibratedPlaytestPreview> {
  final _previewKey = GlobalKey();
  final _viewportKey = GlobalKey();
  late final Timer _timer;
  double _scale = 1;
  String? _signature;
  String? _problem = 'Resolving monitor calibration…';
  bool _reading = false;
  bool _calibrating = false;
  final _calibration = DisplayCalibrationFlow();
  Rect? _lastBounds;
  DisplayCalibrationStore get _store =>
      widget.store ?? DisplayCalibrationStore.instance;
  @override
  void initState() {
    super.initState();
    widget.controller.setPresentationBlocked(true);
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _resolve(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  void _cancel() {
    widget.controller.releaseFocus();
    widget.controller.pause();
  }

  Future<void> _resolve() async {
    if (_reading || _calibrating) return;
    _reading = true;
    try {
      await _store.load();
      final environment = await widget.reader.read();
      if (!mounted || _calibrating) return;
      final viewport = _bounds(_viewportKey);
      final preview = _bounds(_previewKey);
      final visible = viewport == null
          ? null
          : preview?.intersect(viewport) ?? viewport;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final bounds = visible == null
          ? null
          : environment?.physicalBounds(visible, dpr);
      final monitor = bounds == null ? null : environment?.containing(bounds);
      final profile = monitor == null
          ? null
          : _store.resolve(monitor, remote: environment!.remote);
      final problem = environment == null
          ? 'Native display information is unavailable. Restart the Windows editor after rebuilding.'
          : monitor == null
          ? 'Move the preview entirely onto one monitor.'
          : profile == null
          ? 'Calibrate this monitor before continuing.'
          : null;
      widget.controller.setPresentationBlocked(problem != null);
      final display = widget.settings.presentation.display!;
      final scale =
          profile?.scale(
            screenWidthMm: widget.settings.screen.widthMm(display),
            logicalWidth: display.width.toDouble(),
            monitorDpr: dpr,
          ) ??
          _scale;
      if (bounds != _lastBounds ||
          scale != _scale ||
          problem != _problem ||
          monitor?.signature != _signature) {
        _lastBounds = bounds;
        _cancel();
        setState(() {
          _problem = problem;
          _signature = monitor?.signature;
          _scale = scale;
        });
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> _calibrate() async {
    _calibrating = true;
    widget.controller.setPresentationBlocked(true);
    _cancel();
    await _calibration.open(context, reader: widget.reader, store: _store);
    _calibrating = false;
    if (mounted) await _resolve();
  }

  @override
  void dispose() {
    _timer.cancel();
    _calibration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _problem ??
                      'Calibrated physical screen · ${widget.settings.screen.widthMm(widget.settings.presentation.display!).toStringAsFixed(1)} mm wide',
                ),
              ),
              TextButton(
                onPressed: _calibrating ? null : _calibrate,
                child: const Text('Calibrate…'),
              ),
              TextButton(
                onPressed: widget.controller.stop,
                child: const Text('Return to Edit'),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: Stack(
          key: _viewportKey,
          fit: StackFit.expand,
          children: [
            RunnerPlaytestDisplayFrame(
              display: widget.settings.presentation.display,
              scale: _scale,
              previewKey: _previewKey,
              onGeometryChanged: _cancel,
              child: IgnorePointer(
                ignoring: _problem != null,
                child: widget.child,
              ),
            ),
            if (_problem != null)
              const ModalBarrier(dismissible: false, color: Color(0x9905070A)),
          ],
        ),
      ),
    ],
  );
}
