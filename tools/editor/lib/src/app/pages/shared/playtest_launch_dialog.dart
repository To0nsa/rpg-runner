import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';

import 'playtest_display_settings.dart';
import 'display_calibration_dialog.dart';
import '../../../playtest/display_calibration.dart';
import '../../../playtest/playtest_device_screen.dart';

/// Launch-only choices; canceling never captures sources or creates a runtime.
class PlaytestLaunchDialog extends StatefulWidget {
  const PlaytestLaunchDialog({
    super.key,
    required this.title,
    this.initial = EditorPlaytestSettings.initial,
    this.reader = const NativeEditorDisplayReader(),
    this.store,
    this.calibration,
  });

  final EditorPlaytestSettings initial;
  final String title;
  final EditorDisplayReader reader;
  final DisplayCalibrationStore? store;

  /// The enclosing session can retire nested calibration before this route.
  final DisplayCalibrationFlow? calibration;

  @override
  State<PlaytestLaunchDialog> createState() => _PlaytestLaunchDialogState();
}

class _PlaytestLaunchDialogState extends State<PlaytestLaunchDialog> {
  late bool _showHud = widget.initial.presentation.showMobileHud;
  late MovementControlMode _movementMode =
      widget.initial.presentation.movementControlMode;
  final _formKey = GlobalKey<FormState>();
  late RunnerPlaytestDisplay? _display =
      widget.initial.presentation.display ??
      RunnerPlaytestDevicePresets.defaultPhone;

  late PlaytestDeviceScreen? _screen = widget.initial.screen;
  final _anchorKey = GlobalKey();
  bool _busy = false;
  String? _error;
  late final _calibration = widget.calibration ?? DisplayCalibrationFlow();
  DisplayCalibrationStore get _store =>
      widget.store ?? DisplayCalibrationStore.instance;

  Future<bool> _calibrate() =>
      _calibration.open(context, reader: widget.reader, store: _store);

  @override
  void dispose() {
    _calibration.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_busy ||
        !_formKey.currentState!.validate() ||
        _display == null ||
        _screen == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _store.load();
      final environment = await widget.reader.read();
      if (!mounted) return;
      final box = _anchorKey.currentContext?.findRenderObject();
      final monitor = box is RenderBox
          ? environment?.containing(
              environment.physicalBounds(
                box.localToGlobal(Offset.zero) & box.size,
                MediaQuery.devicePixelRatioOf(context),
              ),
            )
          : null;
      if (monitor == null) {
        setState(
          () => _error = 'Move setup onto one monitor. If display support is unavailable, rebuild and restart the Windows editor.',
        );
        return;
      }
      if (_store.resolve(monitor, remote: environment!.remote) == null &&
          !await _calibrate()) {
        return;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        EditorPlaytestSettings(
          screen: _screen!,
          presentation: RunnerPlaytestPresentation(
            showMobileHud: _showHud,
            movementControlMode: _movementMode,
            viewportMode: ViewportScaleMode.pixelPerfectCover,
            display: _display,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title, key: _anchorKey),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaytestDisplaySettings(
                initialScreen: widget.initial.screen,
                onScreenChanged: (screen) => _screen = screen,
                initial:
                    widget.initial.presentation.display ??
                    RunnerPlaytestDevicePresets.defaultPhone,
                onChanged: (display) => _display = display,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                key: const ValueKey('playtest_show_mobile_hud'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show mobile HUD'),
                value: _showHud,
                onChanged: (value) => setState(() => _showHud = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MovementControlMode>(
                key: const ValueKey('playtest_movement_controls'),
                initialValue: _movementMode,
                decoration: const InputDecoration(
                  labelText: 'Movement controls',
                ),
                isExpanded: true,
                items: [
                  for (final mode in MovementControlMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(switch (mode) {
                        MovementControlMode.arrows => 'Arrows',
                        MovementControlMode.joystick => 'Floating joystick',
                        MovementControlMode.fixedJoystick => 'Fixed joystick',
                      }),
                    ),
                ],
                onChanged: _showHud
                    ? (mode) {
                        if (mode != null) setState(() => _movementMode = mode);
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Éloïse starts with her standard equipment, including her shield. Keyboard controls remain available.',
              ),
              const SizedBox(height: 8),
              const Text('Local playtest — no rewards or replay.'),
              TextButton(
                onPressed: _busy ? null : _calibrate,
                child: const Text('Calibrate monitor…'),
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
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _busy ? null : _play, child: const Text('Play')),
    ],
  );
}
