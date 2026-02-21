import '../../core/abilities/ability_def.dart';
import '../../core/combat/status/status.dart';

/// Coarse UI-facing tags derived from [AbilityDef] mechanics.
///
/// These are intentionally semantic and stable for badges/filters.
enum AbilityUiTag {
  offense,
  defense,
  mobility,
  sustain,
  utility,
  singleTarget,
  multiTarget,
  crowdControl,
  dot,
  burst,
  charged,
  staminaSpend,
  manaSpend,
  healthSpend,
  channel,
  guard,
  riposte,
  autoTarget,
  aimed,
}

class AbilityTagContext {
  const AbilityTagContext({
    this.payloadWeaponType,
    this.resolveResourceForContextOnly = false,
  });

  /// Effective payload weapon type for context-sensitive resource tagging.
  final WeaponType? payloadWeaponType;

  /// When true and [payloadWeaponType] is provided, resource tags are derived
  /// from the effective contextual cost instead of all authored cost branches.
  final bool resolveResourceForContextOnly;
}

/// Resolves coarse semantic tags from ability mechanics.
class AbilityTagResolver {
  const AbilityTagResolver({
    StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
  }) : _statusProfiles = statusProfiles;

  final StatusProfileCatalog _statusProfiles;

  Set<AbilityUiTag> resolve(
    AbilityDef def, {
    AbilityTagContext ctx = const AbilityTagContext(),
  }) {
    final tags = <AbilityUiTag>{};
    _addRoleTag(tags, def);
    _addShapeTag(tags, def);
    _addStatusTags(tags, def);
    _addResourceTags(tags, def, ctx);
    _addMechanicTags(tags, def);
    return Set<AbilityUiTag>.unmodifiable(tags);
  }

  void _addRoleTag(Set<AbilityUiTag> tags, AbilityDef def) {
    switch (def.category) {
      case AbilityCategory.melee:
      case AbilityCategory.ranged:
        tags.add(AbilityUiTag.offense);
      case AbilityCategory.defense:
        tags.add(AbilityUiTag.defense);
      case AbilityCategory.mobility:
        tags.add(AbilityUiTag.mobility);
      case AbilityCategory.utility:
        if (_isSustainAbility(def)) {
          tags.add(AbilityUiTag.sustain);
        } else {
          tags.add(AbilityUiTag.utility);
        }
    }
  }

  bool _isSustainAbility(AbilityDef def) {
    if (def.selfStatusProfileId == StatusProfileId.none) return false;
    final status = _statusProfiles.get(def.selfStatusProfileId);
    for (final application in status.applications) {
      if (application.type == StatusEffectType.resourceOverTime) return true;
    }
    return false;
  }

  void _addShapeTag(Set<AbilityUiTag> tags, AbilityDef def) {
    if (!_hasOffensiveDelivery(def)) return;
    if (_isMultiTarget(def)) {
      tags.add(AbilityUiTag.multiTarget);
    } else {
      tags.add(AbilityUiTag.singleTarget);
    }
  }

  bool _hasOffensiveDelivery(AbilityDef def) {
    if (def.hitDelivery is MeleeHitDelivery) return true;
    if (def.hitDelivery is ProjectileHitDelivery) return true;
    if (def.mobilityImpact.hasAnyEffect) return true;
    return false;
  }

  bool _isMultiTarget(AbilityDef def) {
    if (def.targetingModel == TargetingModel.groundTarget ||
        def.targetingModel == TargetingModel.aimedLine) {
      return true;
    }

    final delivery = def.hitDelivery;
    if (delivery is MeleeHitDelivery) return true;
    if (delivery is ProjectileHitDelivery) {
      if (delivery.pierce || delivery.chain || delivery.chainCount > 0) {
        return true;
      }
      if (delivery.hitPolicy == HitPolicy.everyTick) return true;
      return false;
    }

    if (def.mobilityImpact.hasAnyEffect) {
      return def.mobilityImpact.hitPolicy != HitPolicy.once;
    }

    return false;
  }

  void _addStatusTags(Set<AbilityUiTag> tags, AbilityDef def) {
    final profileIds = _collectProfileIds(def);
    for (final id in profileIds) {
      final status = _statusProfiles.get(id);
      for (final application in status.applications) {
        if (application.type == StatusEffectType.dot) {
          tags.add(AbilityUiTag.dot);
        }
        if (_isCrowdControlType(application.type)) {
          tags.add(AbilityUiTag.crowdControl);
        }
      }
    }
  }

  bool _isCrowdControlType(StatusEffectType type) {
    switch (type) {
      case StatusEffectType.stun:
      case StatusEffectType.slow:
      case StatusEffectType.silence:
      case StatusEffectType.drench:
        return true;
      case StatusEffectType.dot:
      case StatusEffectType.haste:
      case StatusEffectType.vulnerable:
      case StatusEffectType.weaken:
      case StatusEffectType.resourceOverTime:
        return false;
    }
  }

  Set<StatusProfileId> _collectProfileIds(AbilityDef def) {
    final profileIds = <StatusProfileId>{};
    if (def.selfStatusProfileId != StatusProfileId.none) {
      profileIds.add(def.selfStatusProfileId);
    }
    if (def.mobilityImpact.statusProfileId != StatusProfileId.none) {
      profileIds.add(def.mobilityImpact.statusProfileId);
    }
    for (final proc in def.procs) {
      if (proc.statusProfileId != StatusProfileId.none) {
        profileIds.add(proc.statusProfileId);
      }
    }
    return profileIds;
  }

  void _addResourceTags(
    Set<AbilityUiTag> tags,
    AbilityDef def,
    AbilityTagContext ctx,
  ) {
    final costs = <AbilityResourceCost>[
      ..._resolveCostBranches(def, ctx),
      def.airJumpCost,
    ];
    for (final cost in costs) {
      if (cost.healthCost100 > 0) tags.add(AbilityUiTag.healthSpend);
      if (cost.staminaCost100 > 0) tags.add(AbilityUiTag.staminaSpend);
      if (cost.manaCost100 > 0) tags.add(AbilityUiTag.manaSpend);
    }
    if (def.holdStaminaDrainPerSecond100 > 0) {
      tags.add(AbilityUiTag.staminaSpend);
    }
  }

  Iterable<AbilityResourceCost> _resolveCostBranches(
    AbilityDef def,
    AbilityTagContext ctx,
  ) sync* {
    if (ctx.resolveResourceForContextOnly && ctx.payloadWeaponType != null) {
      yield def.resolveCostForWeaponType(ctx.payloadWeaponType);
      return;
    }

    yield def.defaultCost;
    final seen = <AbilityResourceCost>{def.defaultCost};
    for (final cost in def.costProfileByWeaponType.values) {
      if (seen.add(cost)) yield cost;
    }
  }

  void _addMechanicTags(Set<AbilityUiTag> tags, AbilityDef def) {
    if (def.chargeProfile != null) {
      tags.add(AbilityUiTag.charged);
      tags.add(AbilityUiTag.burst);
    }

    if (def.holdMode == AbilityHoldMode.holdToMaintain ||
        def.inputLifecycle == AbilityInputLifecycle.holdMaintain) {
      tags.add(AbilityUiTag.channel);
    }

    if (def.damageIgnoredBp > 0) {
      tags.add(AbilityUiTag.guard);
    }

    if (def.grantsRiposteOnGuardedHit) {
      tags.add(AbilityUiTag.riposte);
    }

    if (def.targetingModel == TargetingModel.homing) {
      tags.add(AbilityUiTag.autoTarget);
    } else if (_isAimedAbility(def)) {
      tags.add(AbilityUiTag.aimed);
    }
  }

  bool _isAimedAbility(AbilityDef def) {
    if (def.inputLifecycle == AbilityInputLifecycle.holdRelease) return true;
    switch (def.targetingModel) {
      case TargetingModel.aimed:
      case TargetingModel.aimedLine:
      case TargetingModel.aimedCharge:
      case TargetingModel.groundTarget:
        return true;
      case TargetingModel.none:
      case TargetingModel.directional:
      case TargetingModel.homing:
        return false;
    }
  }
}
