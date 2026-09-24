import '../combat/ai_target_policy.dart';
import '../combat/damage_credit.dart';
import '../combat/faction.dart';
import '../ecs/entity_id.dart';
import '../ecs/systems/npc_combat_lifecycle.dart';
import '../ecs/world.dart';
import 'encounter_definition.dart';
import 'encounter_instance.dart';
import 'encounter_limits.dart';

/// Run-local rescue lifecycle. The coordinator supplies phase boundaries;
/// this owner alone decides participation, terminal outcomes and awards.
final class EncounterSystem {
  final Map<EncounterKey, _EncounterState> _states = {};
  final List<EncounterOutcome> _outcomes = [];
  double? _previousPlayerX;
  double? _previousPlayerY;
  int? _retiredThroughChunk;
  int _rescuedNpcs = 0;
  int _rescuePoints = 0;

  int get rescuedNpcs => _rescuedNpcs;
  int get rescuePoints => _rescuePoints;
  int get retainedEncounters => _states.length;

  EncounterPhase? phase(EncounterKey key) => _states[key]?.phase;
  EncounterOutcome? outcome(EncounterKey key) => _states[key]?.outcome;

  /// Register only newly streamed occurrences. Repeated publication is an error;
  /// it must never reset progress or restore a group that was already resolved.
  void register(
    EncounterOccurrence occurrence, {
    required int tick,
    bool suppressOpening = false,
  }) {
    final key = occurrence.key;
    if (_states.containsKey(key) ||
        (_retiredThroughChunk != null &&
            key.chunkIndex <= _retiredThroughChunk!)) {
      throw StateError('Encounter occurrence $key has already been published.');
    }
    if (_states.length >= EncounterLimits.maxLiveEncounters ||
        _states.keys.where((k) => k.chunkIndex == key.chunkIndex).length >=
            EncounterLimits.maxEncountersPerChunk) {
      _outcomes.add(
        EncounterOutcome(
          key: key,
          phase: EncounterPhase.failed,
          reason: EncounterEndReason.capacity,
          tick: tick,
          diagnostic: 'Encounter occurrence capacity exceeded.',
        ),
      );
      return;
    }
    final state = _EncounterState(occurrence);
    _states[key] = state;
    if (suppressOpening) {
      state.phase = EncounterPhase.skipped;
      final event = EncounterOutcome(
        key: key,
        phase: state.phase,
        reason: EncounterEndReason.openingSuppression,
        tick: tick,
      );
      state.outcome = event;
      _outcomes.add(event);
    }
  }

  /// Call before stream teardown and again after camera motion, before combat.
  void expire(EcsWorld world, {required double cameraLeft, required int tick}) {
    for (final state in _orderedStates()) {
      if (state.unresolved && cameraLeft >= state.occurrence.abandonmentX) {
        _finish(
          world,
          state,
          EncounterPhase.abandoned,
          EncounterEndReason.passedCamera,
          tick,
        );
      }
    }
  }

  /// The sampled center comes from the preceding completed motion step.
  /// Terrain publication precedes this call; motion preparation and AI follow.
  void activate(
    EcsWorld world, {
    required double playerX,
    required double playerY,
    required int tick,
    required EncounterSpawnResult Function(EncounterOccurrence occurrence)
    spawn,
  }) {
    final fromX = _previousPlayerX ?? playerX;
    final fromY = _previousPlayerY ?? playerY;
    _previousPlayerX = playerX;
    _previousPlayerY = playerY;
    for (final state in _orderedStates()) {
      if (state.phase != EncounterPhase.dormant) continue;
      final occurrence = state.occurrence;
      if (!occurrence.definition.trigger.intersectsSweep(
        fromX - occurrence.startX,
        fromY,
        playerX - occurrence.startX,
        playerY,
      )) {
        continue;
      }
      final result = spawn(occurrence);
      if (result is EncounterSpawnRejected) {
        _finish(
          world,
          state,
          EncounterPhase.failed,
          EncounterEndReason.invalidSpawn,
          tick,
          diagnostic: result.diagnostic,
        );
        continue;
      }
      final entities = (result as EncounterSpawned).entities;
      final members = occurrence.participants;
      final valid =
          entities.length == members.length &&
          entities.values.toSet().length == entities.length &&
          members.every(
            (member) =>
                _validSpawn(world, occurrence, member, entities[member.id]),
          );
      if (!valid) {
        // A faulty adapter cannot publish a partial required roster. It returns
        // only newly created actors; never destroy an already-owned participant.
        for (final entity in entities.values.toSet()) {
          if (world.isEntityAlive(entity) && !world.encounterMember.has(entity) &&
              !world.playerInput.has(entity)) {
            world.destroyEntity(entity);
          }
        }
        _finish(
          world,
          state,
          EncounterPhase.failed,
          EncounterEndReason.invalidSpawn,
          tick,
          diagnostic: 'Spawn adapter returned an incomplete or invalid roster.',
        );
        continue;
      }
      for (final member in members) {
        final entity = entities[member.id]!;
        state.entities[member.id] = entity;
        world.encounterMember.add(
          entity,
          key: occurrence.key,
          localId: member.id,
          memberRole: member is EncounterNpcPlacement
              ? EncounterMemberRole.npc
              : EncounterMemberRole.enemy,
        );
      }
      final npcEntities = occurrence.definition.npcs.map(
        (m) => entities[m.id]!,
      );
      final enemyEntities = occurrence.definition.enemies.map(
        (m) => entities[m.id]!,
      );
      for (final member in occurrence.definition.npcs) {
        world.aiTarget.configure(
          entities[member.id]!,
          targetPolicy: AiTargetPolicy.nearestOpponent,
          candidates: enemyEntities,
          playerFallback: false,
        );
      }
      for (final member in occurrence.definition.enemies) {
        world.aiTarget.configure(
          entities[member.id]!,
          targetPolicy:
              member.targetPolicy ?? occurrence.definition.targetPolicy,
          candidates: npcEntities,
        );
      }
      state.phase = EncounterPhase.active;
    }
  }

  /// Connected directly to DamageSystem's positive-HP-loss callback.
  void recordDamage(
    EcsWorld world, {
    required EntityId target,
    required int hpLost100,
    required DamageCredit credit,
  }) {
    if (hpLost100 <= 0 || credit != DamageCredit.player) return;
    final i = world.encounterMember.tryIndexOf(target);
    if (i == null || world.encounterMember.role[i] != EncounterMemberRole.enemy) {
      return;
    }
    final state = _states[world.encounterMember.encounter[i]];
    if (state?.phase == EncounterPhase.active) state!.participated = true;
  }

  /// Resolve after damage and before cleanup. Fatal run state beats same-tick
  /// enemy completion; camera expiry beats member failure and victory.
  void resolve(
    EcsWorld world, {
    required int tick,
    required double cameraLeft,
    bool runEnded = false,
  }) {
    if (runEnded) {
      endRun(world, tick: tick);
      return;
    }
    expire(world, cameraLeft: cameraLeft, tick: tick);
    for (final removal in world.encounterMember.removals) {
      final state = _states[removal.encounter];
      if (state == null || state.phase != EncounterPhase.active) continue;
      final npc = state.occurrence.definition.npcs.any(
        (m) => m.id == removal.memberId,
      );
      if ((removal.defeated && !removal.fatalWorldLoss) ||
          (npc && removal.fatalWorldLoss)) {
        state.defeated.add(removal.memberId);
      } else {
        state.invalidMember = true;
      }
    }
    world.encounterMember.removals.clear();
    for (final state in _orderedStates()) {
      if (state.phase != EncounterPhase.active) continue;
      for (final entry in state.entities.entries) {
        if (state.defeated.contains(entry.key)) continue;
        final mi = world.encounterMember.tryIndexOf(entry.value);
        final hi = world.health.tryIndexOf(entry.value);
        if (mi == null ||
            hi == null ||
            world.encounterMember.encounter[mi] != state.occurrence.key ||
            world.encounterMember.memberId[mi] != entry.key) {
          state.invalidMember = true;
        } else if (world.health.hp[hi] <= 0 ||
            world.deathState.has(entry.value)) {
          state.defeated.add(entry.key);
        }
      }
      final definition = state.occurrence.definition;
      final survivors = definition.npcs
          .where((m) => !state.defeated.contains(m.id))
          .length;
      if (state.invalidMember) {
        _finish(
          world,
          state,
          EncounterPhase.failed,
          EncounterEndReason.invalidMember,
          tick,
        );
      } else if (survivors == 0) {
        _finish(
          world,
          state,
          EncounterPhase.failed,
          EncounterEndReason.npcsDefeated,
          tick,
        );
      } else if (definition.enemies.every(
        (m) => state.defeated.contains(m.id),
      )) {
        _finish(
          world,
          state,
          state.participated ? EncounterPhase.rescued : EncounterPhase.failed,
          state.participated
              ? EncounterEndReason.rescued
              : EncounterEndReason.unassisted,
          tick,
          survivors: survivors,
        );
      }
    }
  }

  void endRun(EcsWorld world, {required int tick}) {
    for (final state in _orderedStates()) {
      if (state.unresolved) {
        _finish(
          world,
          state,
          EncounterPhase.abandoned,
          EncounterEndReason.runEnded,
          tick,
        );
      }
    }
    world.encounterMember.removals.clear();
  }

  /// Unresolved actors must survive ordinary camera-distance cleanup, including
  /// encounter enemies that have moved outside their original chunk.
  bool retainsActor(EcsWorld world, EntityId entity) {
    final i = world.encounterMember.tryIndexOf(entity);
    return i != null &&
        _states[world.encounterMember.encounter[i]]?.phase ==
            EncounterPhase.active;
  }

  bool retainsChunk(int chunkIndex) => _states.values.any(
    (state) => state.occurrence.chunkIndex == chunkIndex && state.unresolved,
  );

  /// Streamer retires chunks in ascending order, after expiry. Terminal records
  /// need no permanent tombstones: the monotonic index prevents reactivation.
  void retireChunk(EcsWorld world, int chunkIndex) {
    if (retainsChunk(chunkIndex)) {
      throw StateError('Cannot retire unresolved encounter terrain.');
    }
    final keys = _states.keys
        .where((key) => key.chunkIndex == chunkIndex)
        .toList();
    for (final key in keys) {
      final state = _states.remove(key)!;
      for (final entity in state.entities.values) {
        final i = world.encounterMember.tryIndexOf(entity);
        if (i != null && world.encounterMember.encounter[i] == key) {
          world.encounterMember.removeEntity(entity);
        }
      }
    }
    if (_retiredThroughChunk == null || chunkIndex > _retiredThroughChunk!) {
      _retiredThroughChunk = chunkIndex;
    }
  }

  List<EncounterOutcome> drainOutcomes() {
    final result = List<EncounterOutcome>.unmodifiable(_outcomes);
    _outcomes.clear();
    return result;
  }

  List<_EncounterState> _orderedStates() => _states.values.toList()
    ..sort((a, b) {
      final chunk = a.occurrence.chunkIndex.compareTo(b.occurrence.chunkIndex);
      return chunk != 0
          ? chunk
          : a.occurrence.definition.id.compareTo(b.occurrence.definition.id);
    });

  bool _validSpawn(
    EcsWorld world,
    EncounterOccurrence occurrence,
    EncounterParticipant member,
    EntityId? entity,
  ) {
    if (entity == null || !world.isEntityAlive(entity) ||
        world.encounterMember.has(entity) ||
        world.playerInput.has(entity) ||
        !world.transform.has(entity) ||
        !world.health.has(entity) ||
        world.health.hp[world.health.indexOf(entity)] <= 0 ||
        world.deathState.has(entity)) {
      return false;
    }
    final factionIndex = world.faction.tryIndexOf(entity);
    if (factionIndex == null) return false;
    if (member is EncounterNpcPlacement) {
      final i = world.npc.tryIndexOf(entity);
      return i != null &&
          world.npc.npcId[i] == member.npcId &&
          !world.npc.protected[i] &&
          world.npc.minX[i] == occurrence.startX &&
          world.npc.maxX[i] == occurrence.endX &&
          !world.enemy.has(entity) &&
          world.faction.faction[factionIndex] == Faction.player;
    }
    final i = world.enemy.tryIndexOf(entity);
    return i != null &&
        world.enemy.enemyId[i] == (member as EncounterEnemyPlacement).enemyId &&
        !world.npc.has(entity) &&
        world.faction.faction[factionIndex] == Faction.enemy;
  }

  void _finish(
    EcsWorld world,
    _EncounterState state,
    EncounterPhase phase,
    EncounterEndReason reason,
    int tick, {
    int survivors = 0,
    String? diagnostic,
  }) {
    if (!state.unresolved) return;
    final definition = state.occurrence.definition;
    final points = phase == EncounterPhase.rescued
        ? survivors *
              (definition.pointsPerNpc ?? EncounterLimits.defaultPointsPerNpc)
        : 0;
    if (phase == EncounterPhase.rescued) {
      _rescuePoints = EncounterLimits.addAward(
        _rescuePoints,
        survivors: survivors,
        points: definition.pointsPerNpc ?? EncounterLimits.defaultPointsPerNpc,
      );
      _rescuedNpcs += survivors;
    }
    state.phase = phase;
    for (final entry in state.entities.entries) {
      final entity = entry.value;
      final i = world.encounterMember.tryIndexOf(entity);
      if (i == null ||
          world.encounterMember.encounter[i] != state.occurrence.key ||
          world.encounterMember.memberId[i] != entry.key) {
        continue;
      }
      if (world.encounterMember.role[i] == EncounterMemberRole.npc) {
        if (!state.defeated.contains(entry.key)) protectNpc(world, entity);
      } else {
        // Preserve health, resources, cooldowns and all committed ability state.
        world.aiTarget.removeEntity(entity);
      }
    }
    final event = EncounterOutcome(
      key: state.occurrence.key,
      phase: phase,
      reason: reason,
      tick: tick,
      survivors: survivors,
      points: points,
      diagnostic: diagnostic,
    );
    state.outcome = event;
    _outcomes.add(event);
  }
}

final class _EncounterState {
  _EncounterState(this.occurrence);
  final EncounterOccurrence occurrence;
  final Map<String, EntityId> entities = {};
  final Set<String> defeated = {};
  EncounterPhase phase = EncounterPhase.dormant;
  EncounterOutcome? outcome;
  bool participated = false;
  bool invalidMember = false;
  bool get unresolved =>
      phase == EncounterPhase.dormant || phase == EncounterPhase.active;
}
