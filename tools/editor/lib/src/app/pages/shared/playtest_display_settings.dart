import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';

import '../../../playtest/playtest_device_screen.dart';

/// Launch-form draft for the shared host's display contract. Invalid custom
/// input emits null, so the enclosing Form can prevent starting a runtime.
class PlaytestDisplaySettings extends StatefulWidget {
  const PlaytestDisplaySettings({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.initialScreen,
    required this.onScreenChanged,
  });

  final RunnerPlaytestDisplay initial;
  final PlaytestDeviceScreen initialScreen;
  final ValueChanged<PlaytestDeviceScreen?> onScreenChanged;
  final ValueChanged<RunnerPlaytestDisplay?> onChanged;

  @override
  State<PlaytestDisplaySettings> createState() =>
      _PlaytestDisplaySettingsState();
}

class _PlaytestDisplaySettingsState extends State<PlaytestDisplaySettings> {
  static const _custom = 'Custom';
  late String _preset =
      RunnerPlaytestDevicePresets.devices.entries
          .where(
            (entry) =>
                entry.value == widget.initial &&
                PlaytestDeviceScreen.presets[entry.key]!.diagonalMm ==
                    widget.initialScreen.diagonalMm,
          )
          .firstOrNull
          ?.key ??
      _custom;
  late final _width = TextEditingController(text: '${widget.initial.width}');
  late final _height = TextEditingController(text: '${widget.initial.height}');
  late final _density = TextEditingController(
    text: '${widget.initial.devicePixelRatio}',
  );

  late final _diagonal = TextEditingController(
    text: widget.initialScreen.diagonalMm.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _density.dispose();
    _diagonal.dispose();
    super.dispose();
  }

  String? _dimensionError(String? text) {
    final value = int.tryParse(text?.trim() ?? '');
    if (value == null ||
        value < RunnerPlaytestDisplay.minDimension ||
        value > RunnerPlaytestDisplay.maxDimension) {
      return 'Enter ${RunnerPlaytestDisplay.minDimension}–${RunnerPlaytestDisplay.maxDimension} whole pixels.';
    }
    return null;
  }

  String? _heightError(String? text) {
    final error = _dimensionError(text);
    if (error != null) return error;
    final width = int.tryParse(_width.text.trim());
    if (width != null && int.parse(text!.trim()) > width) {
      return 'Landscape requires height ≤ width.';
    }
    return null;
  }

  String? _densityError(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    if (value == null ||
        !value.isFinite ||
        value < RunnerPlaytestDisplay.minPixelRatio ||
        value > RunnerPlaytestDisplay.maxPixelRatio) {
      return 'Enter ${RunnerPlaytestDisplay.minPixelRatio}–${RunnerPlaytestDisplay.maxPixelRatio}.';
    }
    return null;
  }

  String? _physicalError(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    return value == null || !value.isFinite || value < 40 || value > 600
        ? 'Enter a measured diagonal from 40 to 600 mm.'
        : null;
  }

  void _notify() {
    widget.onScreenChanged(
      _physicalError(_diagonal.text) == null
          ? PlaytestDeviceScreen.presets[_preset] ??
                PlaytestDeviceScreen(
                  double.parse(_diagonal.text),
                  0.1,
                  'Measured custom screen',
                )
          : null,
    );
    final valid =
        _dimensionError(_width.text) == null &&
        _heightError(_height.text) == null &&
        _densityError(_density.text) == null;
    widget.onChanged(
      valid
          ? RunnerPlaytestDisplay(
              width: int.parse(_width.text.trim()),
              height: int.parse(_height.text.trim()),
              devicePixelRatio: double.parse(_density.text.trim()),
            )
          : null,
    );
  }

  void _select(String? name) {
    if (name == null) return;
    setState(() {
      _preset = name;
      final preset = RunnerPlaytestDevicePresets.devices[name];
      if (preset != null) {
        _width.text = '${preset.width}';
        _height.text = '${preset.height}';
        _density.text = '${preset.devicePixelRatio}';
        _diagonal.text = PlaytestDeviceScreen.presets[name]!.diagonalMm
            .toStringAsFixed(2);
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<String>(
        key: const ValueKey('playtest_display_preset'),
        initialValue: _preset,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Display device'),
        items: [
          for (final name in [
            ...RunnerPlaytestDevicePresets.devices.keys,
            _custom,
          ])
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: _select,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _field(
              key: 'playtest_display_width',
              label: 'Width (logical px)',
              controller: _width,
              validator: _dimensionError,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              key: 'playtest_display_height',
              label: 'Height (logical px)',
              controller: _height,
              validator: _heightError,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _field(
        key: 'playtest_display_density',
        label: 'Pixel density (DPR)',
        controller: _density,
        validator: _densityError,
        decimal: true,
      ),
      const SizedBox(height: 12),
      _field(
        key: 'playtest_screen_diagonal',
        label: 'Active screen diagonal (mm)',
        controller: _diagonal,
        validator: _physicalError,
        decimal: true,
      ),
      const SizedBox(height: 8),
      const Text(
        'Actual-size landscape preview. Game and HUD keep the calibrated screen size; scrollbars reveal overflow. iPad Mini represents the 5th generation.',
      ),
    ],
  );

  Widget _field({
    required String key,
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    bool decimal = false,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: _preset == _custom,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label, errorMaxLines: 2),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: validator,
    onChanged: (_) => _notify(),
  );
}
