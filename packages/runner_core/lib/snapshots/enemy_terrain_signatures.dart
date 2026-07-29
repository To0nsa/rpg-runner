import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../collision/terrain/terrain_edge_id.dart';
import '../enemies/enemy_id.dart';

/// One deterministic intent/action entry in an enemy terrain scenario.
///
/// Values are already quantized by the caller. [order] resolves multiple
/// actions scheduled for the same tick without depending on insertion order.
final class EnemyTerrainScheduleSignatureRecord {
  const EnemyTerrainScheduleSignatureRecord({
    required this.tick,
    required this.order,
    required this.actorProfile,
    required this.kind,
    this.value0 = 0,
    this.value1 = 0,
  });

  final int tick;
  final int order;
  final String actorProfile;
  final String kind;
  final int value0;
  final int value1;
}

/// Canonical integer/string checkpoint for one terrain-owned enemy.
///
/// This record intentionally combines motion, support, navigation, contact,
/// teleport/combat, and lifecycle state. It is a reviewed determinism input,
/// not a renderer snapshot or gameplay mutation API.
final class EnemyTerrainCheckpointSignatureRecord {
  const EnemyTerrainCheckpointSignatureRecord({
    required this.tick,
    required this.entityId,
    required this.enemyId,
    required this.bodyXTicks,
    required this.bodyYTicks,
    required this.velocityXTicks,
    required this.velocityYTicks,
    required this.bundleVersion,
    required this.grounded,
    required this.navGraphVersion,
    required this.currentSurfaceId,
    required this.lastGroundSurfaceId,
    required this.targetSurfaceId,
    required this.activeEdgeIndex,
    required this.pathCursor,
    required this.pathEdges,
    required this.hitLeft,
    required this.hitRight,
    required this.hitCeiling,
    required this.contactEdgeIds,
    required this.teleportCode,
    required this.combatCommitCode,
    required this.lifecycleCode,
    this.supportEdgeId,
  });

  final int tick;
  final int entityId;
  final EnemyId enemyId;
  final int bodyXTicks;
  final int bodyYTicks;
  final int velocityXTicks;
  final int velocityYTicks;
  final int bundleVersion;
  final bool grounded;
  final TerrainEdgeId? supportEdgeId;
  final int navGraphVersion;
  final int currentSurfaceId;
  final int lastGroundSurfaceId;
  final int targetSurfaceId;
  final int activeEdgeIndex;
  final int pathCursor;
  final List<int> pathEdges;
  final bool hitLeft;
  final bool hitRight;
  final bool hitCeiling;
  final List<TerrainEdgeId> contactEdgeIds;
  final String teleportCode;
  final String combatCommitCode;
  final String lifecycleCode;
}

/// Stable named result for scenario-specific state outside actor checkpoints.
final class EnemyTerrainOutcomeSignatureRecord {
  const EnemyTerrainOutcomeSignatureRecord({
    required this.key,
    this.value = 0,
    this.code = '',
  });

  final String key;
  final int value;
  final String code;
}

/// Complete deterministic evidence for one `SG-E##` scenario.
final class EnemyTerrainScenarioSignatureInput {
  const EnemyTerrainScenarioSignatureInput({
    required this.scenarioId,
    required this.fixtureId,
    required this.seed,
    required this.actorProfiles,
    required this.schedule,
    required this.checkpoints,
    required this.outcomes,
    required this.legacyDisposition,
  });

  final String scenarioId;
  final String fixtureId;
  final int seed;
  final List<String> actorProfiles;
  final List<EnemyTerrainScheduleSignatureRecord> schedule;
  final List<EnemyTerrainCheckpointSignatureRecord> checkpoints;
  final List<EnemyTerrainOutcomeSignatureRecord> outcomes;
  final String legacyDisposition;
}

/// Top-level input for the reviewed `enemy-terrain-run-v1` SHA-256 digest.
final class EnemyTerrainRunSignatureInput {
  const EnemyTerrainRunSignatureInput({
    required this.surfaceSignature,
    required this.graphSignature,
    required this.scenarios,
  });

  final String surfaceSignature;
  final String graphSignature;
  final List<EnemyTerrainScenarioSignatureInput> scenarios;
}

/// Canonical UTF-8 records underlying [enemyTerrainRunSignatureV1].
///
/// Scenario collections and unordered metadata are sorted explicitly. Path
/// and contact lists retain their gameplay-significant order. Every numeric
/// value is an integer and every enum-like value is a stable code/name.
List<String> enemyTerrainRunCanonicalRecordsV1(
  EnemyTerrainRunSignatureInput input,
) {
  _requireSha256(input.surfaceSignature, 'surfaceSignature');
  _requireSha256(input.graphSignature, 'graphSignature');
  final scenarios = List<EnemyTerrainScenarioSignatureInput>.of(input.scenarios)
    ..sort((left, right) => left.scenarioId.compareTo(right.scenarioId));
  final seenScenarioIds = <String>{};
  for (final scenario in scenarios) {
    if (!RegExp(r'^SG-E(?:0[1-9]|1[0-5])$').hasMatch(scenario.scenarioId)) {
      throw ArgumentError.value(
        scenario.scenarioId,
        'scenarioId',
        'Expected SG-E01 through SG-E15.',
      );
    }
    if (!seenScenarioIds.add(scenario.scenarioId)) {
      throw ArgumentError('Enemy terrain scenario IDs must be unique.');
    }
  }
  final expectedScenarioIds = <String>{
    for (var index = 1; index <= 15; index += 1)
      'SG-E${index.toString().padLeft(2, '0')}',
  };
  if (!seenScenarioIds.containsAll(expectedScenarioIds) ||
      seenScenarioIds.length != expectedScenarioIds.length) {
    throw ArgumentError(
      'Enemy terrain runs must contain every SG-E01 through SG-E15 scenario.',
    );
  }

  final records = <String>[
    _canonicalRecord(<String>[
      'enemy-terrain-run-v1',
      input.surfaceSignature,
      input.graphSignature,
      scenarios.length.toString(),
    ]),
  ];
  for (final scenario in scenarios) {
    final profiles = List<String>.of(scenario.actorProfiles)..sort();
    records.add(
      _canonicalRecord(<String>[
        'enemy-terrain-scenario-v1',
        scenario.scenarioId,
        scenario.fixtureId,
        scenario.seed.toString(),
        profiles.length.toString(),
        ...profiles,
        scenario.legacyDisposition,
      ]),
    );

    final schedule = List<EnemyTerrainScheduleSignatureRecord>.of(
      scenario.schedule,
    )..sort(_compareSchedule);
    for (final entry in schedule) {
      records.add(
        _canonicalRecord(<String>[
          'enemy-terrain-schedule-v1',
          scenario.scenarioId,
          entry.tick.toString(),
          entry.order.toString(),
          entry.actorProfile,
          entry.kind,
          entry.value0.toString(),
          entry.value1.toString(),
        ]),
      );
    }

    final checkpoints = List<EnemyTerrainCheckpointSignatureRecord>.of(
      scenario.checkpoints,
    )..sort(_compareCheckpoints);
    for (final checkpoint in checkpoints) {
      final fields = <String>[
        'enemy-terrain-checkpoint-v1',
        scenario.scenarioId,
        checkpoint.tick.toString(),
        checkpoint.entityId.toString(),
        checkpoint.enemyId.name,
        checkpoint.bodyXTicks.toString(),
        checkpoint.bodyYTicks.toString(),
        checkpoint.velocityXTicks.toString(),
        checkpoint.velocityYTicks.toString(),
        checkpoint.bundleVersion.toString(),
        checkpoint.grounded ? '1' : '0',
        checkpoint.supportEdgeId?.canonicalKey ?? '',
        checkpoint.navGraphVersion.toString(),
        checkpoint.currentSurfaceId.toString(),
        checkpoint.lastGroundSurfaceId.toString(),
        checkpoint.targetSurfaceId.toString(),
        checkpoint.activeEdgeIndex.toString(),
        checkpoint.pathCursor.toString(),
        checkpoint.pathEdges.length.toString(),
        ...checkpoint.pathEdges.map((edge) => edge.toString()),
        checkpoint.hitLeft ? '1' : '0',
        checkpoint.hitRight ? '1' : '0',
        checkpoint.hitCeiling ? '1' : '0',
        checkpoint.contactEdgeIds.length.toString(),
        ...checkpoint.contactEdgeIds.map((edge) => edge.canonicalKey),
        checkpoint.teleportCode,
        checkpoint.combatCommitCode,
        checkpoint.lifecycleCode,
      ];
      records.add(_canonicalRecord(fields));
    }

    final outcomes = List<EnemyTerrainOutcomeSignatureRecord>.of(
      scenario.outcomes,
    )..sort(_compareOutcomes);
    final seenOutcomeKeys = <String>{};
    for (final outcome in outcomes) {
      if (!seenOutcomeKeys.add(outcome.key)) {
        throw ArgumentError(
          '${scenario.scenarioId} outcome keys must be unique.',
        );
      }
      records.add(
        _canonicalRecord(<String>[
          'enemy-terrain-outcome-v1',
          scenario.scenarioId,
          outcome.key,
          outcome.value.toString(),
          outcome.code,
        ]),
      );
    }
    records.add(
      _canonicalRecord(<String>[
        'enemy-terrain-scenario-end-v1',
        scenario.scenarioId,
        schedule.length.toString(),
        checkpoints.length.toString(),
        outcomes.length.toString(),
      ]),
    );
  }
  return List<String>.unmodifiable(records);
}

/// SHA-256 digest of [enemyTerrainRunCanonicalRecordsV1].
String enemyTerrainRunSignatureV1(EnemyTerrainRunSignatureInput input) => sha256
    .convert(utf8.encode(enemyTerrainRunCanonicalRecordsV1(input).join('\n')))
    .toString();

int _compareSchedule(
  EnemyTerrainScheduleSignatureRecord left,
  EnemyTerrainScheduleSignatureRecord right,
) {
  var order = left.tick.compareTo(right.tick);
  if (order != 0) return order;
  order = left.order.compareTo(right.order);
  if (order != 0) return order;
  order = left.actorProfile.compareTo(right.actorProfile);
  if (order != 0) return order;
  order = left.kind.compareTo(right.kind);
  if (order != 0) return order;
  order = left.value0.compareTo(right.value0);
  if (order != 0) return order;
  return left.value1.compareTo(right.value1);
}

int _compareCheckpoints(
  EnemyTerrainCheckpointSignatureRecord left,
  EnemyTerrainCheckpointSignatureRecord right,
) {
  var order = left.tick.compareTo(right.tick);
  if (order != 0) return order;
  order = left.entityId.compareTo(right.entityId);
  if (order != 0) return order;
  order = left.enemyId.index.compareTo(right.enemyId.index);
  if (order != 0) return order;
  return _checkpointTieKey(left).compareTo(_checkpointTieKey(right));
}

String _checkpointTieKey(EnemyTerrainCheckpointSignatureRecord checkpoint) =>
    _canonicalRecord(<String>[
      checkpoint.bodyXTicks.toString(),
      checkpoint.bodyYTicks.toString(),
      checkpoint.velocityXTicks.toString(),
      checkpoint.velocityYTicks.toString(),
      checkpoint.bundleVersion.toString(),
      checkpoint.grounded ? '1' : '0',
      checkpoint.supportEdgeId?.canonicalKey ?? '',
      checkpoint.navGraphVersion.toString(),
      checkpoint.currentSurfaceId.toString(),
      checkpoint.lastGroundSurfaceId.toString(),
      checkpoint.targetSurfaceId.toString(),
      checkpoint.activeEdgeIndex.toString(),
      checkpoint.pathCursor.toString(),
      ...checkpoint.pathEdges.map((edge) => edge.toString()),
      checkpoint.hitLeft ? '1' : '0',
      checkpoint.hitRight ? '1' : '0',
      checkpoint.hitCeiling ? '1' : '0',
      ...checkpoint.contactEdgeIds.map((edge) => edge.canonicalKey),
      checkpoint.teleportCode,
      checkpoint.combatCommitCode,
      checkpoint.lifecycleCode,
    ]);

int _compareOutcomes(
  EnemyTerrainOutcomeSignatureRecord left,
  EnemyTerrainOutcomeSignatureRecord right,
) {
  var order = left.key.compareTo(right.key);
  if (order != 0) return order;
  order = left.value.compareTo(right.value);
  if (order != 0) return order;
  return left.code.compareTo(right.code);
}

void _requireSha256(String value, String name) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, name, 'Must be a lowercase SHA-256.');
  }
}

String _canonicalRecord(List<String> fields) =>
    fields.map((field) => '${utf8.encode(field).length}:$field').join('|');
