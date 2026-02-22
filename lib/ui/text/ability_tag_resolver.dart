import '../../core/abilities/ability_def.dart';
import '../../core/combat/status/status.dart';

/// Coarse UI-facing tags derived from [AbilityDef] mechanics.
///
/// These are intentionally semantic and stable for badges/filters.
enum AbilityUiTag {
  damage,
  defense,
  dash,
  jump,
  hold,
  utility,
  crowdControl,
  charged,
  autoTarget,
  aimed,
}

/// Resolves coarse semantic tags from ability mechanics.
class AbilityTagResolver {
  const AbilityTagResolver({
    StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
  }) : _statusProfiles = statusProfiles;

  final StatusProfileCatalog _statusProfiles;

  Set<AbilityUiTag> resolve(AbilityDef def) {
    final tags = <AbilityUiTag>{};
    _addRoleTag(tags, def);
    _addStatusTags(tags, def);
    _addMechanicTags(tags, def);
    return Set<AbilityUiTag>.unmodifiable(tags);
  }

  void _addRoleTag(Set<AbilityUiTag> tags, AbilityDef def) {
    switch (def.category) {
      case AbilityCategory.melee:
      case AbilityCategory.ranged:
        tags.add(AbilityUiTag.damage);
      case AbilityCategory.defense:
        tags.add(AbilityUiTag.defense);
      case AbilityCategory.mobility:
        if (def.allowedSlots.contains(AbilitySlot.mobility)) {
          tags.add(AbilityUiTag.dash);
        }
        if (def.allowedSlots.contains(AbilitySlot.jump)) {
          tags.add(AbilityUiTag.jump);
        }
      case AbilityCategory.utility:
        tags.add(AbilityUiTag.utility);
    }
  }

  void _addStatusTags(Set<AbilityUiTag> tags, AbilityDef def) {
    final profileIds = _collectProfileIds(def);
    for (final id in profileIds) {
      final status = _statusProfiles.get(id);
      for (final application in status.applications) {
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

  void _addMechanicTags(Set<AbilityUiTag> tags, AbilityDef def) {
    if (def.chargeProfile != null) {
      tags.add(AbilityUiTag.charged);
    }

    if (def.holdMode == AbilityHoldMode.holdToMaintain ||
        def.inputLifecycle == AbilityInputLifecycle.holdMaintain) {
      tags.add(AbilityUiTag.hold);
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
