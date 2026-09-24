import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';

/// Stable scene identity independent of canonical sort order and actor type.
final class ChunkEncounterSelection {
  const ChunkEncounterSelection(this.encounterId, {this.memberId});
  final String encounterId;
  final String? memberId;

  @override
  bool operator ==(Object other) =>
      other is ChunkEncounterSelection &&
      other.encounterId == encounterId &&
      other.memberId == memberId;
  @override
  int get hashCode => Object.hash(encounterId, memberId);
}

EncounterDefinition? findChunkEncounter(
  Iterable<EncounterDefinition> groups,
  String id,
) => groups.where((e) => e.id == id).firstOrNull;

EncounterParticipant? findEncounterMember(
  EncounterDefinition group,
  String id,
) => [...group.npcs, ...group.enemies].where((e) => e.id == id).firstOrNull;

/// Retains explicit zero/equal-default overrides unless default mode is selected.
EncounterDefinition editEncounter(
  EncounterDefinition before, {
  String? id,
  String? name,
  EncounterTrigger? trigger,
  AiTargetPolicy? targetPolicy,
  int? pointsPerNpc,
  bool useDefaultPoints = false,
  Iterable<EncounterNpcPlacement>? npcs,
  Iterable<EncounterEnemyPlacement>? enemies,
}) => EncounterDefinition(
  id: id ?? before.id,
  name: name ?? before.name,
  trigger: trigger ?? before.trigger,
  targetPolicy: targetPolicy ?? before.targetPolicy,
  pointsPerNpc: useDefaultPoints ? null : pointsPerNpc ?? before.pointsPerNpc,
  npcs: npcs ?? before.npcs,
  enemies: enemies ?? before.enemies,
);

EncounterNpcPlacement editEncounterNpc(
  EncounterNpcPlacement before, {
  String? id,
  NpcId? npcId,
  double? x,
  Facing? facing,
  SpawnPlacementMode? placement,
}) => EncounterNpcPlacement(
  id: id ?? before.id,
  npcId: npcId ?? before.npcId,
  x: x ?? before.x,
  facing: facing ?? before.facing,
  placement: placement ?? before.placement,
);

EncounterEnemyPlacement editEncounterEnemy(
  EncounterEnemyPlacement before, {
  String? id,
  EnemyId? enemyId,
  double? x,
  Facing? facing,
  SpawnPlacementMode? placement,
  AiTargetPolicy? targetPolicy,
  bool useEncounterPolicy = false,
}) => EncounterEnemyPlacement(
  id: id ?? before.id,
  enemyId: enemyId ?? before.enemyId,
  x: x ?? before.x,
  facing: facing ?? before.facing,
  placement: placement ?? before.placement,
  targetPolicy: useEncounterPolicy ? null : targetPolicy ?? before.targetPolicy,
);

/// Replacing a member keeps its identity; changing roles requires an explicit delete/add.
EncounterDefinition replaceEncounterMember(
  EncounterDefinition group,
  EncounterParticipant member,
) {
  final previous = findEncounterMember(group, member.id);
  if (previous == null || previous.runtimeType != member.runtimeType) {
    throw ArgumentError(
      'The selected participant no longer belongs to this role.',
    );
  }
  return editEncounter(
    group,
    npcs: [
      for (final old in group.npcs)
        old.id == member.id ? member as EncounterNpcPlacement : old,
    ],
    enemies: [
      for (final old in group.enemies)
        old.id == member.id ? member as EncounterEnemyPlacement : old,
    ],
  );
}

EncounterDefinition removeEncounterMember(
  EncounterDefinition group,
  String id,
) {
  if (findEncounterMember(group, id) == null) {
    throw ArgumentError('Unknown participant $id.');
  }
  return editEncounter(
    group,
    npcs: group.npcs.where((e) => e.id != id),
    enemies: group.enemies.where((e) => e.id != id),
  );
}

EncounterDefinition addEncounterMember(
  EncounterDefinition group,
  EncounterParticipant member,
) => editEncounter(
  group,
  npcs: [...group.npcs, if (member is EncounterNpcPlacement) member],
  enemies: [...group.enemies, if (member is EncounterEnemyPlacement) member],
);

/// Generates an unused source ID without coupling identity to display names.
String nextEncounterSourceId(String base, Iterable<String> existing) {
  final used = existing.toSet();
  if (!used.contains(base)) return base;
  for (var n = 2; ; n++) {
    final suffix = '_$n';
    final prefix = base.length + suffix.length <= 64
        ? base
        : base.substring(0, 64 - suffix.length);
    final candidate = '$prefix$suffix';
    if (!used.contains(candidate)) return candidate;
  }
}

EncounterDefinition duplicateChunkEncounter(
  EncounterDefinition group,
  Iterable<EncounterDefinition> existing,
) => editEncounter(
  group,
  id: nextEncounterSourceId(group.id, existing.map((e) => e.id)),
  name: '${group.name} copy',
);

/// Duplication keeps position and policy; only the local member identity changes.
EncounterParticipant duplicateEncounterMember(
  EncounterDefinition group,
  EncounterParticipant member,
) {
  final id = nextEncounterSourceId(
    member.id,
    [...group.npcs, ...group.enemies].map((e) => e.id),
  );
  return switch (member) {
    EncounterNpcPlacement() => editEncounterNpc(member, id: id),
    EncounterEnemyPlacement() => editEncounterEnemy(member, id: id),
  };
}
