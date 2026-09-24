import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_limits.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';

/// Strict shared Chunk-v2 decoder. Incomplete roles are saveable; runtime
/// readiness separately requires a complete, placeable rescue roster.
List<EncounterDefinition> decodeEncounterDefinitions(
  Object? value, {
  required String sourcePath,
  required int chunkWidth,
  required int chunkHeight,
}) {
  final records = _list(value, sourcePath);
  if (records.length > EncounterLimits.maxEncountersPerChunk) {
    throw FormatException('$sourcePath exceeds the encounter capacity.');
  }
  final result = <EncounterDefinition>[];
  for (var i = 0; i < records.length; i++) {
    final path = '$sourcePath[$i]';
    final json = _object(records[i], path);
    _keys(
      json,
      {'id', 'name', 'trigger', 'targetPolicy', 'npcs', 'enemies'},
      {'pointsPerNpc'},
      path,
    );
    final trigger = _object(json['trigger'], '$path.trigger');
    _keys(trigger, {'x', 'y', 'width', 'height'}, {}, '$path.trigger');
    try {
      final rectangle = EncounterTrigger(
        x: _int(trigger, 'x', '$path.trigger').toDouble(),
        y: _int(trigger, 'y', '$path.trigger').toDouble(),
        width: _int(trigger, 'width', '$path.trigger').toDouble(),
        height: _int(trigger, 'height', '$path.trigger').toDouble(),
      );
      if (rectangle.y < 0 || rectangle.y + rectangle.height > chunkHeight) {
        throw FormatException('$path.trigger must fit the chunk height.');
      }
      final npcs = <EncounterNpcPlacement>[];
      final enemies = <EncounterEnemyPlacement>[];
      for (final role in ['npcs', 'enemies']) {
        final members = _list(json[role], '$path.$role');
        final capacity = role == 'npcs'
            ? EncounterLimits.maxNpcsPerEncounter
            : EncounterLimits.maxEnemiesPerEncounter;
        if (members.length > capacity) {
          throw FormatException(
            '$path.$role exceeds the participant capacity.',
          );
        }
        for (var j = 0; j < members.length; j++) {
          final memberPath = '$path.$role[$j]';
          final member = _object(members[j], memberPath);
          final isNpc = role == 'npcs';
          _keys(
            member,
            {'id', isNpc ? 'npcId' : 'enemyId', 'x', 'facing', 'placement'},
            isNpc ? {} : {'targetPolicy'},
            memberPath,
          );
          final id = _string(member, 'id', memberPath);
          final x = _int(member, 'x', memberPath).toDouble();
          final facing = _enum(
            member['facing'],
            Facing.values,
            '$memberPath.facing',
          );
          final placement = _enum(
            member['placement'],
            SpawnPlacementMode.values,
            '$memberPath.placement',
          );
          if (isNpc) {
            npcs.add(
              EncounterNpcPlacement(
                id: id,
                x: x,
                facing: facing,
                placement: placement,
                npcId: _enum(
                  member['npcId'],
                  NpcId.values,
                  '$memberPath.npcId',
                ),
              ),
            );
          } else {
            enemies.add(
              EncounterEnemyPlacement(
                id: id,
                x: x,
                facing: facing,
                placement: placement,
                enemyId: _enum(
                  member['enemyId'],
                  EnemyId.values,
                  '$memberPath.enemyId',
                ),
                targetPolicy: member.containsKey('targetPolicy')
                    ? _enum(
                        member['targetPolicy'],
                        AiTargetPolicy.values,
                        '$memberPath.targetPolicy',
                      )
                    : null,
              ),
            );
          }
        }
      }
      _ordered(npcs.map((m) => m.id), '$path.npcs');
      _ordered(enemies.map((m) => m.id), '$path.enemies');
      final definition = EncounterDefinition(
        id: _string(json, 'id', path),
        name: _string(json, 'name', path),
        trigger: rectangle,
        targetPolicy: _enum(
          json['targetPolicy'],
          AiTargetPolicy.values,
          '$path.targetPolicy',
        ),
        pointsPerNpc: json.containsKey('pointsPerNpc')
            ? _int(json, 'pointsPerNpc', path)
            : null,
        npcs: npcs,
        enemies: enemies,
      );
      definition.validateForChunk(
        chunkWidth.toDouble(),
        requireComplete: false,
      );
      result.add(definition);
    } on ArgumentError catch (error) {
      throw FormatException('$path: ${error.message}');
    }
  }
  _ordered(result.map((e) => e.id), sourcePath);
  return List.unmodifiable(result);
}

/// Canonical source copies preserve explicit zero and equal-default awards.
List<Map<String, Object>> encounterDefinitionsToJson(
  Iterable<EncounterDefinition> definitions, {
  bool canonical = false,
}) => [
  for (final e in _copyOrder(definitions, (e) => e.id, canonical))
    {
      'id': e.id,
      'name': e.name,
      'trigger': {
        'x': _whole(e.trigger.x),
        'y': _whole(e.trigger.y),
        'width': _whole(e.trigger.width),
        'height': _whole(e.trigger.height),
      },
      'targetPolicy': e.targetPolicy.name,
      if (e.pointsPerNpc != null) 'pointsPerNpc': e.pointsPerNpc!,
      'npcs': [
        for (final n in _copyOrder(e.npcs, (n) => n.id, canonical))
          {
            'id': n.id,
            'npcId': n.npcId.name,
            'x': _whole(n.x),
            'facing': n.facing.name,
            'placement': n.placement.name,
          },
      ],
      'enemies': [
        for (final n in _copyOrder(e.enemies, (n) => n.id, canonical))
          {
            'id': n.id,
            'enemyId': n.enemyId.name,
            'x': _whole(n.x),
            'facing': n.facing.name,
            'placement': n.placement.name,
            if (n.targetPolicy != null) 'targetPolicy': n.targetPolicy!.name,
          },
      ],
    },
];

List<T> _copyOrder<T>(
  Iterable<T> values,
  String Function(T) id,
  bool canonical,
) {
  final copy = values.toList();
  if (canonical) copy.sort((a, b) => id(a).compareTo(id(b)));
  return copy;
}

int _whole(double value) {
  if (!value.isFinite || value != value.roundToDouble()) {
    throw ArgumentError('Encounter source coordinates must be whole pixels.');
  }
  return value.toInt();
}

List<dynamic> _list(Object? value, String path) =>
    value is List ? value : throw FormatException('$path must be an array.');
Map<String, dynamic> _object(Object? value, String path) =>
    value is Map<String, dynamic>
    ? value
    : throw FormatException('$path must be an object.');
void _keys(
  Map<String, dynamic> json,
  Set<String> required,
  Set<String> optional,
  String path,
) {
  if (!required.every(json.containsKey) ||
      !json.keys.every((k) => required.contains(k) || optional.contains(k))) {
    throw FormatException(
      '$path requires ${required.join(', ')} and allows only ${optional.join(', ')} additionally.',
    );
  }
}

int _int(Map<String, dynamic> json, String key, String path) => json[key] is int
    ? json[key] as int
    : throw FormatException('$path.$key must be an integer.');
String _string(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$path.$key must be a nonempty trimmed string.');
  }
  return value;
}

T _enum<T extends Enum>(Object? value, List<T> values, String path) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException(
    '$path must be one of ${values.map((v) => v.name).join(', ')}.',
  );
}

void _ordered(Iterable<String> ids, String path) {
  String? previous;
  for (final id in ids) {
    if (previous != null && previous.compareTo(id) >= 0) {
      throw FormatException('$path IDs must be unique and sorted.');
    }
    previous = id;
  }
}
