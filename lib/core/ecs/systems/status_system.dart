import '../../combat/damage.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../events/game_event.dart';
import '../../util/double_math.dart';
import '../../util/tick_math.dart';
import '../entity_id.dart';
import '../stores/status/bleed_store.dart';
import '../stores/status/burn_store.dart';
import '../stores/status/slow_store.dart';
import '../world.dart';

/// Applies status effects and ticks active statuses.
class StatusSystem {
  StatusSystem({
    required int tickHz,
    StatusProfileCatalog profiles = const StatusProfileCatalog(),
  }) : _tickHz = tickHz,
       _profiles = profiles;

  final int _tickHz;
  final StatusProfileCatalog _profiles;

  final List<StatusRequest> _pending = <StatusRequest>[];
  final List<EntityId> _removeScratch = <EntityId>[];

  /// Queues a status profile to apply.
  void queue(StatusRequest request) {
    if (request.profileId == StatusProfileId.none) return;
    _pending.add(request);
  }

  /// Ticks existing statuses and queues DoT damage.
  void tickExisting(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
  ) {
    _tickBurn(world, queueDamage);
    _tickBleed(world, queueDamage);
    _tickSlow(world);
  }

  /// Applies queued statuses and refreshes derived modifiers.
  void applyQueued(EcsWorld world) {
    if (_pending.isNotEmpty) {
      _applyPending(world);
      _pending.clear();
    }
    _refreshMoveSpeed(world);
  }

  void _tickBurn(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
  ) {
    final burn = world.burn;
    if (burn.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < burn.denseEntities.length; i += 1) {
      final target = burn.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }
      burn.ticksLeft[i] -= 1;
      if (burn.ticksLeft[i] <= 0) {
        _removeScratch.add(target);
        continue;
      }

      burn.periodTicksLeft[i] -= 1;
      if (burn.periodTicksLeft[i] <= 0) {
        burn.periodTicksLeft[i] = burn.periodTicks[i];
        queueDamage(
          DamageRequest(
            target: target,
            amount: burn.damagePerTick[i],
            damageType: DamageType.fire,
            sourceKind: DeathSourceKind.statusEffect,
          ),
        );
      }
    }
    for (final target in _removeScratch) {
      burn.removeEntity(target);
    }
  }

  void _tickBleed(
    EcsWorld world,
    void Function(DamageRequest request) queueDamage,
  ) {
    final bleed = world.bleed;
    if (bleed.denseEntities.isEmpty) return;

    _removeScratch.clear();
    for (var i = 0; i < bleed.denseEntities.length; i += 1) {
      final target = bleed.denseEntities[i];
      if (world.deathState.has(target)) {
        _removeScratch.add(target);
        continue;
      }
      bleed.ticksLeft[i] -= 1;
      if (bleed.ticksLeft[i] <= 0) {
        _removeScratch.add(target);
        continue;
      }

      bleed.periodTicksLeft[i] -= 1;
      if (bleed.periodTicksLeft[i] <= 0) {
        bleed.periodTicksLeft[i] = bleed.periodTicks[i];
        queueDamage(
          DamageRequest(
            target: target,
            amount: bleed.damagePerTick[i],
            damageType: DamageType.bleed,
            sourceKind: DeathSourceKind.statusEffect,
          ),
        );
      }
    }
    for (final target in _removeScratch) {
      bleed.removeEntity(target);
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

  void _applyPending(EcsWorld world) {
    final resistance = world.damageResistance;
    final immunity = world.statusImmunity;
    final invuln = world.invulnerability;

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
          final mod = resistance.modForEntity(req.target, req.damageType);
          if (mod > 0.0) {
            magnitude *= 1.0 + mod;
          }
        }
        if (magnitude <= 0.0) continue;

        switch (app.type) {
          case StatusEffectType.slow:
            _applySlow(world, req.target, magnitude, app.durationSeconds);
          case StatusEffectType.burn:
            _applyDot(
              world,
              target: req.target,
              magnitude: magnitude,
              durationSeconds: app.durationSeconds,
              periodSeconds: app.periodSeconds,
              useBurn: true,
            );
          case StatusEffectType.bleed:
            _applyDot(
              world,
              target: req.target,
              magnitude: magnitude,
              durationSeconds: app.durationSeconds,
              periodSeconds: app.periodSeconds,
              useBurn: false,
            );
        }
      }
    }
  }

  void _applySlow(
    EcsWorld world,
    EntityId target,
    double magnitude,
    double durationSeconds,
  ) {
    if (!world.statModifier.has(target)) return;
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final slow = world.slow;
    final clamped = clampDouble(magnitude, 0.0, 0.9);
    final index = slow.tryIndexOf(target);
    if (index == null) {
      slow.add(
        target,
        SlowDef(ticksLeft: ticksLeft, magnitude: clamped),
      );
    } else {
      slow.ticksLeft[index] = slow.ticksLeft[index] > ticksLeft
          ? slow.ticksLeft[index]
          : ticksLeft;
      if (clamped > slow.magnitude[index]) {
        slow.magnitude[index] = clamped;
      }
    }
  }

  void _applyDot(
    EcsWorld world, {
    required EntityId target,
    required double magnitude,
    required double durationSeconds,
    required double periodSeconds,
    required bool useBurn,
  }) {
    final ticksLeft = ticksFromSecondsCeil(durationSeconds, _tickHz);
    if (ticksLeft <= 0) return;

    final periodTicks = periodSeconds <= 0.0
        ? 1
        : ticksFromSecondsCeil(periodSeconds, _tickHz);
    final periodSecondsResolved = periodTicks / _tickHz;
    final damagePerTick = magnitude * periodSecondsResolved;

    if (useBurn) {
      final burn = world.burn;
      final index = burn.tryIndexOf(target);
      if (index == null) {
        burn.add(
          target,
          BurnDef(
            ticksLeft: ticksLeft,
            periodTicks: periodTicks,
            damagePerTick: damagePerTick,
          ),
        );
      } else {
        burn.ticksLeft[index] =
            burn.ticksLeft[index] > ticksLeft ? burn.ticksLeft[index] : ticksLeft;
        if (damagePerTick > burn.damagePerTick[index]) {
          burn.damagePerTick[index] = damagePerTick;
        }
        burn.periodTicks[index] = periodTicks;
        burn.periodTicksLeft[index] = periodTicks;
      }
      return;
    }

    final bleed = world.bleed;
    final index = bleed.tryIndexOf(target);
    if (index == null) {
      bleed.add(
        target,
        BleedDef(
          ticksLeft: ticksLeft,
          periodTicks: periodTicks,
          damagePerTick: damagePerTick,
        ),
      );
    } else {
      bleed.ticksLeft[index] =
          bleed.ticksLeft[index] > ticksLeft ? bleed.ticksLeft[index] : ticksLeft;
      if (damagePerTick > bleed.damagePerTick[index]) {
        bleed.damagePerTick[index] = damagePerTick;
      }
      bleed.periodTicks[index] = periodTicks;
      bleed.periodTicksLeft[index] = periodTicks;
    }
  }

  void _refreshMoveSpeed(EcsWorld world) {
    final mods = world.statModifier;
    if (mods.denseEntities.isEmpty) return;

    for (var i = 0; i < mods.denseEntities.length; i += 1) {
      mods.moveSpeedMul[i] = 1.0;
    }

    final slow = world.slow;
    if (slow.denseEntities.isEmpty) return;

    for (var i = 0; i < slow.denseEntities.length; i += 1) {
      final target = slow.denseEntities[i];
      final mi = mods.tryIndexOf(target);
      if (mi == null) continue;
      final multiplier = clampDouble(1.0 - slow.magnitude[i], 0.1, 1.0);
      mods.moveSpeedMul[mi] = multiplier;
    }
  }
}
