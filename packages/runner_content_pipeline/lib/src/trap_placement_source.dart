import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/traps/trap_geometry.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/traps/trap_validation.dart';

/// One canonical decoder for editor and generator trap placements. Callers
/// supply [] only for an absent field; explicit null and coercion fail closed.
List<TrapPlacement> decodeTrapPlacements(
  Object? value, {
  required String sourcePath,
  required int chunkWidth,
  required int chunkHeight,
}) {
  if (value is! List) throw FormatException('$sourcePath must be an array.');
  final placements = <TrapPlacement>[];
  for (var i = 0; i < value.length; i++) {
    final path = '$sourcePath[$i]', json = value[i];
    if (json is! Map<String, dynamic> || json['trapId'] is! String) {
      throw FormatException('$path requires a string trapId.');
    }
    final id = TrapId.fromSourceKey(json['trapId'] as String);
    final fields = {
      'trapId',
      'x',
      'y',
      'trigger',
      if (id != TrapId.spike) 'facing',
    };
    _keys(json, fields, path);
    final trigger = json['trigger'];
    if (trigger is! Map<String, dynamic>) {
      throw FormatException('$path.trigger must be an object.');
    }
    _keys(trigger, {'offsetX', 'offsetY', 'width', 'height'}, '$path.trigger');
    final facing = id == TrapId.spike
        ? Facing.right
        : switch (json['facing']) {
            'left' => Facing.left,
            'right' => Facing.right,
            _ => throw FormatException('$path.facing must be left or right.'),
          };
    placements.add(
      TrapPlacement(
        trapId: id,
        x: _int(json, 'x', path),
        y: _int(json, 'y', path),
        facing: facing,
        trigger: TrapRect(
          _int(trigger, 'offsetX', path),
          _int(trigger, 'offsetY', path),
          _int(trigger, 'width', path),
          _int(trigger, 'height', path),
        ),
      ),
    );
  }
  try {
    validateTrapPlacements(
      placements,
      chunkWidth: chunkWidth,
      chunkHeight: chunkHeight,
    );
  } on ArgumentError catch (e) {
    throw FormatException('$sourcePath: ${e.message}');
  }
  return List.unmodifiable(placements);
}

void _keys(Map<String, dynamic> json, Set<String> fields, String path) {
  if (json.length != fields.length || !json.keys.every(fields.contains)) {
    throw FormatException('$path must contain exactly ${fields.join(', ')}.');
  }
}

int _int(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$path.$key must be a whole pixel integer.');
  }
  return value;
}
