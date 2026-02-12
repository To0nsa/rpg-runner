import '../../combat/damage.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../events/game_event.dart';
import '../../stats/character_stats_resolver.dart';
import '../../stats/resolved_stats_cache.dart';
import '../../util/tick_math.dart';
import '../../util/fixed_math.dart';
import '../../util/double_math.dart';
import '../entity_id.dart';
import '../stores/status/dot_store.dart';
import '../stores/status/haste_store.dart';
import '../stores/status/slow_store.dart';
import '../stores/status/vulnerable_store.dart';
import '../../combat/control_lock.dart';
import '../world.dart';

/// Applies status effects and ticks active statuses.
class StatusSystem {
  StatusSystem({
    required int tickHz,
    StatusProfileCatalog profiles = const StatusProfileCatalog(),
    CharacterStatsResolver statsResolver = const CharacterStatsResolver(),
    ResolvedStatsCache? statsCache,
  }) : _tickHz = tickHz,
       _profiles = profiles,
       _statsCache = statsCache ?? ResolvedStatsCache(resolver: statsResolver);

  final int _tickHz;
  final StatusProfileCatalog _profiles;
  final ResolvedStatsCache _statsCache;

  final List<StatusRequest> _pending = <StatusRequest>[];
  final List<EntityId> _removeScratch = <EntityId>[];

  /// Current tick, set at the start of applyQueued.
  int _currentTick = 0;

  /// Queues a status profile to apply.
  void queue(StatusRequest request) {
    if (request.profileId == StatusProfileId.none) return;
    _pending.add(request);
  }

  /// Ticks existing statuses and queues DoT damage.
  void tickExisting(EcsWorld world) {
    _tickDot(world);
    _tickHaste(world);
    _tickSlow(world);
    _tickVulnerable(world);
  }

  /// Applies queued statuses and refreshes derived modifiers.
  void applyQueued(EcsWorld world, {required int currentTick}) {
    _currentTick = currentTick;
    if (_pending.isNotEmpty) {
      _applyPending(world);
      _pending.clear();
    }
    _refreshMoveSpeed(world);
  }

  void _tickDot(EcsWorld world) {
    final dot = world.dot;
    if (dot.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < dot.denseEntities.length; i += 1) {
      final target = dot.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }

      var channel = dot.damageTypes[i].length - 1;
      while (channel >= 0) {
        dot.ticksLeft[i][channel] -= 1;
        if (dot.ticksLeft[i][channel] <= 0) {
          dot.removeChannelAtEntityIndex(i, channel);
          channel -= 1;
          continue;
        }

        dot.periodTicksLeft[i][channel] -= 1;
        if (dot.periodTicksLeft[i][channel] <= 0) {
          dot.periodTicksLeft[i][channel] = dot.periodTicks[i][channel];
          final amount100 =
              (dot.dps100[i][channel] * dot.periodTicks[i][channel]) ~/ _tickHz;
          world.damageQueue.add(
            DamageRequest(
              target: target,
              amount100: amount100,
              damageType: dot.damageTypes[i][channel],
              sourceKind: DeathSourceKind.statusEffect,
            ),
          );
        }
        channel -= 1;
      }

      if (dot.hasNoChannelsEntityIndex(i)) {
        _removeScratch.add(target);
      }
    }
    for (final target in _removeScratch) {
      dot.removeEntity(target);
    }
  }

  void _tickSlow(EcsWorld world) {
    final slow = world.slow;
    if (slow.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < slow.denseEntities.length; i += 1) {
      final target = slow.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }
      slow.ticksLeft[i] -= 1;
      if (slow.ticksLeft[i] <= 0) {
        _removeScratch.add(target);
      }
    }
    for (final target in _removeScratch) {
      slow.removeEntity(target);
    }
  }

  void _tickHaste(EcsWorld world) {
    final haste = world.haste;
    if (haste.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < haste.denseEntities.length; i += 1) {
      final target = haste.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }
      haste.ticksLeft[i] -= 1;
      if (haste.ticksLeft[i] <= 0) {
        _removeScratch.add(target);
      }
    }
    for (final target in _removeScratch) {
      haste.removeEntity(target);
    }
  }

  void _applyPending(EcsWorld world) {
    final resistance = world.damageResistance;
    final immunity = world.statusImmunity;
    final invuln = world.invulnerability;
    final resolvedStatsByTarget = <EntityId, ResolvedCharacterStats>{};

    for (final req in _pending) {
      if (world.deathState.has(req.target)) continue;
      if (!world.health.has(req.target)) continue;

      final ii = invuln.tryIndexOf(req.target);
      if (ii != null && invuln.ticksLeft[ii] > 0) continue;

      final profile = _profiles.get(req.profileId);
      if (profile.applications.isEmpty) continue;

      for (final app in profile.applications) {
        if (immunity.isImmune(req.target, app.type)) continue;

        var magnitude = app.magnitude;
        if (app.scaleByDamageType) {
          final baseTypedModBp = resistance.modBpForEntity(
            req.target,
            req.damageType,
          );
          final resolved = resolvedStatsByTarget.putIfAbsent(
            req.target,
            () => _statsCache.resolveForEntity(world, req.target),
          );
          final gearTypedModBp = resolved.incomingDamageModBpForDamageType(
            req.damageType,
          );
          final modBp = baseTypedModBp + gearTypedModBp;
          if (modBp > 0) {
            magnitude = applyBp(magnitude, modBp);
          }
        }
        if (magnitude <= 0) continue;

        switch (app.type) {
          case StatusEffectType.dot:
            final dotDamageType = app.dotDamageType;
            if (dotDamageType == null) {
              assert(
                false,
                'StatusEffectType.dot requires dotDamageType in StatusApplication.',
              );
              continue;
            }
            _applyDot(
              world,
              target: req.target,
              magnitude: magnitude,
              durationSeconds: app.durationSeconds,
              periodSeconds: app.periodSeconds,
              damageType: dotDamageType,
            );
          case StatusEffectType.slow:
            _applySlow(world, req.target, magnitude, app.durationSeconds);
          case StatusEffectType.haste:
            _applyHaste(world, req.target, magnitude, app.durationSeconds);
          case StatusEffectType.stun:
            _applyStun(world, req.target, magnitude, app.durationSeconds);
          case StatusEffectType.vulnerable:
            _applyVulnerable(world, req.target, magnitude, app.durationSeconds);
        }
      }
    }
  }

  void _applyStun(
    EcsWorld world,
    EntityId target,
    int magnitude,
    double durationSeconds,
  ) {
    // Stun requires statModifier for moveSpeedMul (and arguably any status effect target)
    if (!world.statModifier.has(target)) return;
    final durationTicks = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (durationTicks <= 0) return;

    // Add stun lock via ControlLockStore
    world.controlLock.addLock(
      target,
      LockFlag.stun,
      durationTicks,
      _currentTick,
    );

    // Hard cancel active intents to prevent ghost execution
    if (world.meleeIntent.has(target)) {
      world.meleeIntent.tick[world.meleeIntent.indexOf(target)] = -1;
    }
    if (world.projectileIntent.has(target)) {
      world.projectileIntent.tick[world.projectileIntent.indexOf(target)] = -1;
    }
    if (world.selfIntent.has(target)) {
      world.selfIntent.tick[world.selfIntent.indexOf(target)] = -1;
    }
    // Cancel dash if active
    final mi = world.movement.tryIndexOf(target);
    if (mi != null && world.movement.dashTicksLeft[mi] > 0) {
      world.movement.dashTicksLeft[mi] = 0;
    }
  }

  void _applySlow(
    EcsWorld world,
    EntityId target,
    int magnitude,
    double durationSeconds,
  ) {
    if (!world.statModifier.has(target)) return;
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final slow = world.slow;
    final clamped = clampInt(magnitude, 0, 9000);
    final index = slow.tryIndexOf(target);
    if (index == null) {
      slow.add(target, SlowDef(ticksLeft: ticksLeft, magnitude: clamped));
    } else {
      final currentMagnitude = slow.magnitude[index];
      if (clamped > currentMagnitude) {
        slow.magnitude[index] = clamped;
        slow.ticksLeft[index] = ticksLeft;
      } else if (clamped == currentMagnitude) {
        if (ticksLeft > slow.ticksLeft[index]) {
          slow.ticksLeft[index] = ticksLeft;
        }
      }
    }
  }

  void _applyHaste(
    EcsWorld world,
    EntityId target,
    int magnitude,
    double durationSeconds,
  ) {
    if (!world.statModifier.has(target)) return;
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final haste = world.haste;
    final clamped = clampInt(magnitude, 0, 20000);
    final index = haste.tryIndexOf(target);
    if (index == null) {
      haste.add(target, HasteDef(ticksLeft: ticksLeft, magnitude: clamped));
    } else {
      final currentMagnitude = haste.magnitude[index];
      if (clamped > currentMagnitude) {
        haste.magnitude[index] = clamped;
        haste.ticksLeft[index] = ticksLeft;
      } else if (clamped == currentMagnitude) {
        if (ticksLeft > haste.ticksLeft[index]) {
          haste.ticksLeft[index] = ticksLeft;
        }
      }
    }
  }

  void _applyVulnerable(
    EcsWorld world,
    EntityId target,
    int magnitude,
    double durationSeconds,
  ) {
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final vulnerable = world.vulnerable;
    final clamped = clampInt(magnitude, 0, 9000);
    final index = vulnerable.tryIndexOf(target);
    if (index == null) {
      vulnerable.add(
        target,
        VulnerableDef(ticksLeft: ticksLeft, magnitude: clamped),
      );
    } else {
      final currentMagnitude = vulnerable.magnitude[index];
      if (clamped > currentMagnitude) {
        vulnerable.magnitude[index] = clamped;
        vulnerable.ticksLeft[index] = ticksLeft;
      } else if (clamped == currentMagnitude) {
        if (ticksLeft > vulnerable.ticksLeft[index]) {
          vulnerable.ticksLeft[index] = ticksLeft;
        }
      }
    }
  }

  void _applyDot(
    EcsWorld world, {
    required EntityId target,
    required int magnitude,
    required double durationSeconds,
    required double periodSeconds,
    required DamageType damageType,
  }) {
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final periodTicks = periodSeconds <= 0.0
        ? 1
        : ticksFromSecondsCeil(periodSeconds, _tickHz);
    final dps100 = magnitude;

    final dot = world.dot;
    final index = dot.tryIndexOf(target);
    if (index == null) {
      dot.add(
        target,
        DotDef(
          damageType: damageType,
          ticksLeft: ticksLeft,
          periodTicks: periodTicks,
          dps100: dps100,
        ),
      );
      return;
    }

    final channelIndex = dot.channelIndexForEntityIndex(index, damageType);
    if (channelIndex == null) {
      dot.addChannel(
        target,
        DotDef(
          damageType: damageType,
          ticksLeft: ticksLeft,
          periodTicks: periodTicks,
          dps100: dps100,
        ),
      );
      return;
    }

    final currentDps = dot.dps100[index][channelIndex];
    if (dps100 > currentDps) {
      dot.setChannel(
        target,
        channelIndex,
        DotDef(
          damageType: damageType,
          ticksLeft: ticksLeft,
          periodTicks: periodTicks,
          dps100: dps100,
        ),
      );
      return;
    }

    if (dps100 == currentDps &&
        ticksLeft > dot.ticksLeft[index][channelIndex]) {
      dot.ticksLeft[index][channelIndex] = ticksLeft;
    }
  }

  void _refreshMoveSpeed(EcsWorld world) {
    final mods = world.statModifier;
    if (mods.denseEntities.isEmpty) return;

    for (var i = 0; i < mods.denseEntities.length; i += 1) {
      mods.moveSpeedMul[i] = 1.0;
    }

    final slow = world.slow;
    if (slow.denseEntities.isNotEmpty) {
      for (var i = 0; i < slow.denseEntities.length; i += 1) {
        final target = slow.denseEntities[i];
        final mi = mods.tryIndexOf(target);
        if (mi == null) continue;
        final slowBp = slow.magnitude[i];
        mods.moveSpeedMul[mi] -= slowBp / bpScale;
      }
    }

    final haste = world.haste;
    if (haste.denseEntities.isNotEmpty) {
      for (var i = 0; i < haste.denseEntities.length; i += 1) {
        final target = haste.denseEntities[i];
        final mi = mods.tryIndexOf(target);
        if (mi == null) continue;
        final hasteBp = haste.magnitude[i];
        mods.moveSpeedMul[mi] += hasteBp / bpScale;
      }
    }

    for (var i = 0; i < mods.denseEntities.length; i += 1) {
      mods.moveSpeedMul[i] = clampDouble(mods.moveSpeedMul[i], 0.1, 2.0);
    }
  }

  void _tickVulnerable(EcsWorld world) {
    final vulnerable = world.vulnerable;
    if (vulnerable.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < vulnerable.denseEntities.length; i += 1) {
      final target = vulnerable.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }
      vulnerable.ticksLeft[i] -= 1;
      if (vulnerable.ticksLeft[i] <= 0) {
        _removeScratch.add(target);
      }
    }
    for (final target in _removeScratch) {
      vulnerable.removeEntity(target);
    }
  }
}
