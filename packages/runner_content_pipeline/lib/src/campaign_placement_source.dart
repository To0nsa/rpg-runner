import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/traps/trap_placement.dart';

import 'campaign_source.dart';
import 'encounter_source.dart';
import 'trap_placement_source.dart';

/// Stable authoring identities are independent of route and list positions.
/// Runtime mechanics remain in Core; source records retain editable metadata.
sealed class CampaignPlacementSource {
  const CampaignPlacementSource(this.id);

  final String id;
  CampaignPoint get position;
  String get missionChunkId => position.missionChunkId;
  Map<String, Object?> toJson();
}

/// A null resource means a gold coin; resource types use existing gem rules.
final class CampaignPickupSource extends CampaignPlacementSource {
  const CampaignPickupSource(super.id, this.position, {this.resource});
  @override
  final CampaignPoint position;
  final RestorationStat? resource;
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': resource == null ? 'gold' : 'gem',
    'position': campaignPointToJson(position),
    if (resource != null) 'resource': resource!.name,
  };
}

final class CampaignEnemySource extends CampaignPlacementSource {
  const CampaignEnemySource(
    super.id,
    this.position, {
    required this.marker,
    required this.required,
    this.returnWhenPlayerRetreats = true,
  });
  @override
  final CampaignPoint position;
  final SpawnMarker marker;
  final bool returnWhenPlayerRetreats;
  final bool required;
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': 'enemy',
    'position': campaignPointToJson(position),
    'enemyId': marker.enemyId.name,
    'placement': marker.placement.name,
    'chancePercent': marker.chancePercent,
    'salt': marker.salt,
    if (!returnWhenPlayerRetreats) 'returnWhenPlayerRetreats': false,
    'required': required,
  };
}

final class CampaignTrapSource extends CampaignPlacementSource {
  const CampaignTrapSource(super.id, this.missionChunkId, this.trap);
  @override
  final String missionChunkId;
  final TrapPlacement trap;
  @override
  CampaignPoint get position => CampaignPoint(
    missionChunkId: missionChunkId,
    x: trap.x.toDouble(),
    y: trap.y.toDouble(),
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': 'trap',
    'missionChunkId': missionChunkId,
    'trap': trap.toJson(),
  };
}

final class CampaignRescueSource extends CampaignPlacementSource {
  const CampaignRescueSource(
    super.id,
    this.missionChunkId,
    this.encounter, {
    required this.required,
  });
  @override
  final String missionChunkId;
  final EncounterDefinition encounter;
  final bool required;
  @override
  CampaignPoint get position => CampaignPoint(
    missionChunkId: missionChunkId,
    x: encounter.trigger.x,
    y: encounter.trigger.y,
  );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': 'rescue',
    'missionChunkId': missionChunkId,
    'encounter': encounterDefinitionsToJson([encounter]).single,
    'required': required,
  };
}

/// The effect attaches to captured collision lineage; it adds no geometry.
final class CampaignShrineSource extends CampaignPlacementSource {
  const CampaignShrineSource(
    super.id,
    this.position, {
    required this.prefabKey,
    required this.placementKey,
    required this.shapeId,
    required this.appearance,
    required this.activationWidth,
    required this.scale,
  });
  @override
  final CampaignPoint position;
  final String? prefabKey, placementKey;
  final String shapeId;
  final WorldInteractionAppearanceId appearance;
  final double activationWidth, scale;

  WorldInteractionBinding bindingFor(String chunkKey) =>
      WorldInteractionBinding(
        key: id,
        chunkKey: chunkKey,
        prefabKey: prefabKey,
        placementKey: placementKey,
        shapeId: shapeId,
        missionChunkId: missionChunkId,
        surfaceX: position.x,
        activationWidth: activationWidth,
        scaleOverride: scale,
        interactionId: WorldInteractionId.regenerationShrine,
        appearanceId: appearance,
      );
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'kind': 'shrine',
    'position': campaignPointToJson(position),
    'prefabKey': prefabKey,
    'placementKey': placementKey,
    'shapeId': shapeId,
    'appearance': appearance.name,
    'activationWidth': activationWidth,
    'scale': scale,
  };
}

/// Strict additive schema-1 field: absence is handled by the mission decoder;
/// explicit null, unknown properties and duplicate identities are rejected.
List<CampaignPlacementSource> decodeCampaignPlacements(Object? raw) {
  if (raw is! List || raw.length > 512) {
    throw const FormatException(
      'placements must be an array of at most 512 objects.',
    );
  }
  final ids = <String>{};
  return List.unmodifiable(
    raw.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Each placement must be an object.');
      }
      final id = _id(value['id']);
      if (!ids.add(id)) throw FormatException('Duplicate placement $id.');
      final kind = value['kind'];
      final keys = switch (kind) {
        'gold' => {'position'},
        'gem' => {'position', 'resource'},
        'enemy' => {
          'position',
          'enemyId',
          'placement',
          'chancePercent',
          'salt',
          if (value.containsKey('returnWhenPlayerRetreats'))
            'returnWhenPlayerRetreats',
          'required',
        },
        'trap' => {'missionChunkId', 'trap'},
        'rescue' => {'missionChunkId', 'encounter', 'required'},
        'shrine' => {
          'position',
          'prefabKey',
          'placementKey',
          'shapeId',
          'appearance',
          'activationWidth',
          'scale',
        },
        _ => throw FormatException('Unknown campaign placement kind $kind.'),
      }..addAll({'id', 'kind'});
      if (value.length != keys.length || !value.keys.every(keys.contains)) {
        throw FormatException('$id requires exactly ${keys.join(', ')}.');
      }
      switch (kind) {
        case 'gold':
        case 'gem':
          return CampaignPickupSource(
            id,
            campaignPointFromJson(value['position']),
            resource: kind == 'gold'
                ? null
                : _enum(value['resource'], RestorationStat.values),
          );
        case 'shrine':
          String? reference(Object? v) {
            if (v == null) return null;
            if (v is! String || v.isEmpty || v.length > 1024) {
              throw const FormatException('Invalid shrine support reference.');
            }
            return v;
          }
          double number(Object? v, double max) {
            if (v is! num || !v.isFinite || v <= 0 || v > max) {
              throw FormatException('Expected positive value at most $max.');
            }
            return v.toDouble();
          }
          return CampaignShrineSource(
            id,
            campaignPointFromJson(value['position']),
            prefabKey: reference(value['prefabKey']),
            placementKey: reference(value['placementKey']),
            shapeId:
                reference(value['shapeId']) ??
                (throw const FormatException('Shrine support is required.')),
            appearance: _enum(
              value['appearance'],
              WorldInteractionAppearanceId.values,
            ),
            activationWidth: number(value['activationWidth'], 600),
            scale: number(value['scale'], 10),
          );
        case 'enemy':
          final point = campaignPointFromJson(value['position']);
          final enemy = _enum(value['enemyId'], EnemyId.values);
          if (enemy.isArenaOnly) {
            throw FormatException('$id: bosses require an arena.');
          }
          return CampaignEnemySource(
            id,
            point,
            marker: SpawnMarker(
              enemyId: enemy,
              x: point.x,
              placement: _enum(value['placement'], SpawnPlacementMode.values),
              chancePercent: _integer(value['chancePercent'], 0, 100),
              salt: _integer(value['salt'], 0, 2147483647),
            ),
            required: _bool(value['required']),
            returnWhenPlayerRetreats:
                value.containsKey('returnWhenPlayerRetreats')
                ? _bool(value['returnWhenPlayerRetreats'])
                : true,
          );
        case 'trap':
          return CampaignTrapSource(
            id,
            _missionChunkId(value['missionChunkId']),
            decodeTrapPlacements(
              [value['trap']],
              sourcePath: id,
              chunkWidth: 600,
              chunkHeight: 270,
            ).single,
          );
        case 'rescue':
          final encounter = decodeEncounterDefinitions(
            [value['encounter']],
            sourcePath: id,
            chunkWidth: 600,
            chunkHeight: 270,
          ).single;
          if (encounter.id != id) {
            throw FormatException(
              '$id: rescue and placement identity must match.',
            );
          }
          return CampaignRescueSource(
            id,
            _missionChunkId(value['missionChunkId']),
            encounter,
            required: _bool(value['required']),
          );
        default:
          throw FormatException('Unknown campaign placement kind $kind.');
      }
    }),
  );
}

String _id(Object? value) {
  if (value is! String || !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(value)) {
    throw const FormatException(
      'Placement identities must be snake_case (max 64 characters).',
    );
  }
  return value;
}

String _missionChunkId(Object? value) =>
    campaignPointFromJson({'missionChunkId': value, 'x': 0, 'y': 0})
        .missionChunkId;

T _enum<T extends Enum>(Object? value, List<T> values) => values.firstWhere(
  (item) => item.name == value,
  orElse: () => throw FormatException('Unknown catalog value $value.'),
);
bool _bool(Object? value) =>
    value is bool ? value : throw const FormatException('Expected boolean.');
int _integer(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw FormatException('Expected integer in $min..$max.');
  }
  return value;
}
