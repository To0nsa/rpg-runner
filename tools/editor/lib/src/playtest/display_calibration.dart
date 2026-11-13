import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Physical pixels, not Flutter logical pixels. No device-emulation DPR here.
class EditorMonitor {
  const EditorMonitor({
    required this.id,
    required this.name,
    required this.bounds,
    required this.orientation,
    required this.identified,
  });
  final String id;
  final String name;
  final Rect bounds;
  final int orientation;
  final bool identified;
  String get signature =>
      '$id|${bounds.width.toInt()}x${bounds.height.toInt()}|$orientation';
}

class EditorDisplayEnvironment {
  const EditorDisplayEnvironment({
    required this.origin,
    required this.monitors,
    required this.remote,
  });
  final Offset origin;
  final List<EditorMonitor> monitors;
  final bool remote;

  Rect physicalBounds(Rect logicalBounds, double monitorDpr) => Rect.fromLTWH(
    origin.dx + logicalBounds.left * monitorDpr,
    origin.dy + logicalBounds.top * monitorDpr,
    logicalBounds.width * monitorDpr,
    logicalBounds.height * monitorDpr,
  );

  /// A clipped preview can overflow its viewport, but its visible pixels must
  /// belong to one monitor. Straddling never borrows a neighbour's calibration.
  EditorMonitor? containing(Rect physicalBounds) {
    final matches = monitors.where(
      (m) =>
          m.bounds.left <= physicalBounds.left &&
          m.bounds.top <= physicalBounds.top &&
          m.bounds.right >= physicalBounds.right &&
          m.bounds.bottom >= physicalBounds.bottom,
    );
    return matches.length == 1 ? matches.single : null;
  }
}

abstract interface class EditorDisplayReader {
  Future<EditorDisplayEnvironment?> read();
}

class NativeEditorDisplayReader implements EditorDisplayReader {
  const NativeEditorDisplayReader();
  static const _channel = MethodChannel('lothringen.editor/display');
  @override
  Future<EditorDisplayEnvironment?> read() async {
    try {
      final data = await _channel.invokeMapMethod<String, Object?>('read');
      if (data == null) return null;
      double number(Map<Object?, Object?> m, String key) =>
          (m[key] as num).toDouble();
      return EditorDisplayEnvironment(
        origin: Offset(number(data, 'originX'), number(data, 'originY')),
        remote: data['remote'] == true,
        monitors: [
          for (final raw in data['monitors'] as List)
            if (raw case final Map<Object?, Object?> m)
              EditorMonitor(
                id: m['id'] as String,
                name: m['name'] as String,
                bounds: Rect.fromLTWH(
                  number(m, 'left'),
                  number(m, 'top'),
                  number(m, 'width'),
                  number(m, 'height'),
                ),
                orientation: m['orientation'] as int,
                identified: m['identified'] == true,
              ),
        ],
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class DisplayCalibration {
  DisplayCalibration({
    required this.signature,
    required this.pixelsPerMm,
    required this.label,
  }) {
    if (signature.isEmpty ||
        label.isEmpty ||
        !pixelsPerMm.isFinite ||
        pixelsPerMm < 1 ||
        pixelsPerMm > 40) {
      throw ArgumentError('Invalid monitor calibration.');
    }
  }
  final String signature;
  final double pixelsPerMm;
  final String label;

  double scale({
    required double screenWidthMm,
    required double logicalWidth,
    required double monitorDpr,
  }) {
    if (!screenWidthMm.isFinite ||
        screenWidthMm <= 0 ||
        logicalWidth <= 0 ||
        monitorDpr <= 0) {
      throw ArgumentError('Positive finite display dimensions required.');
    }
    return pixelsPerMm * screenWidthMm / (monitorDpr * logicalWidth);
  }

  Map<String, Object> toJson() => {
    'signature': signature,
    'pixelsPerMm': pixelsPerMm,
    'label': label,
  };
  factory DisplayCalibration.fromJson(Map<String, Object?> json) =>
      DisplayCalibration(
        signature: json['signature'] as String,
        pixelsPerMm: (json['pixelsPerMm'] as num).toDouble(),
        label: json['label'] as String,
      );
}

/// Machine-local editor preferences, separate from authored content and product
/// settings. Corrupt/stale entries remain unresolved and can be recalibrated.
class DisplayCalibrationStore {
  DisplayCalibrationStore({File? file}) : _file = file;
  static final instance = DisplayCalibrationStore(
    file: File(
      '${Platform.environment['LOCALAPPDATA'] ?? Platform.environment['HOME'] ?? Directory.systemTemp.path}'
      '/LothringenEditor/display_calibration_v1.json',
    ),
  );
  final File? _file;
  final Map<String, DisplayCalibration> _profiles = {};
  final Map<String, DisplayCalibration> _confirmedProfiles = {};
  Future<void>? _loading;
  Future<void> load() => _loading ??= _read();
  Future<void> _read() async {
    try {
      final file = _file;
      if (file == null || !await file.exists()) return;
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (data['version'] != 1) return;
      for (final raw in data['profiles'] as List) {
        try {
          final profile = DisplayCalibration.fromJson(
            Map<String, Object?>.from(raw as Map),
          );
          _profiles[profile.signature] = profile;
        } on Object {
          /* An invalid entry cannot become a physical-size claim. */
        }
      }
    } on Object {
      /* Calibration remains available even after a corrupt file. */
    }
  }

  Iterable<DisplayCalibration> get profiles => _profiles.values;
  DisplayCalibration? resolve(EditorMonitor monitor, {required bool remote}) {
    if (_confirmedProfiles[monitor.signature] case final profile?) {
      return profile;
    }
    if (!monitor.identified || remote) return null;
    return _profiles[monitor.signature];
  }

  Future<void> save(DisplayCalibration profile) async {
    await load();
    final values = {..._profiles, profile.signature: profile};
    if (_file case final file?) {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'version': 1,
          'profiles': values.values.map((p) => p.toJson()).toList(),
        }),
        flush: true,
      );
    }
    _profiles[profile.signature] = profile;
    _confirmedProfiles[profile.signature] = profile;
  }

  /// Manual selection confirms a measured profile for this session only when
  /// monitor identity is unreliable (including remote desktop).
  void confirm(EditorMonitor monitor, DisplayCalibration profile) {
    _confirmedProfiles[monitor.signature] = DisplayCalibration(
      signature: monitor.signature,
      pixelsPerMm: profile.pixelsPerMm,
      label: profile.label,
    );
  }
}
