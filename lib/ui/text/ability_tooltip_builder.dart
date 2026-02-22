import '../../core/abilities/ability_def.dart';
import '../../core/combat/status/status.dart';
import '../../core/projectiles/projectile_id.dart';
import 'ability_tag_resolver.dart';
import 'ability_text.dart';

abstract interface class StatusTextResolver {
  StatusText? describe(StatusProfileId id);
}

class StatusText {
  const StatusText({required this.name, this.durationSeconds});

  final String name;
  final double? durationSeconds;
}

class AbilityCostLine {
  const AbilityCostLine({required this.label, required this.value});

  final String label;
  final String value;
}

class AbilityTooltipContext {
  const AbilityTooltipContext({
    this.selectedProjectileSpellId,
    this.payloadWeaponType,
    this.statusTextResolver,
  });

  final ProjectileId? selectedProjectileSpellId;
  final WeaponType? payloadWeaponType;
  final StatusTextResolver? statusTextResolver;
}

class AbilityTooltip {
  const AbilityTooltip({
    required this.title,
    required this.description,
    this.badges = const <String>[],
    this.tags = const <AbilityUiTag>{},
    this.cooldownSeconds,
    this.costLines = const <AbilityCostLine>[],
  });

  final String title;
  final String description;
  final List<String> badges;
  final Set<AbilityUiTag> tags;
  final double? cooldownSeconds;
  final List<AbilityCostLine> costLines;
}

abstract interface class AbilityTooltipBuilder {
  AbilityTooltip build(
    AbilityDef def, {
    AbilityTooltipContext ctx = const AbilityTooltipContext(),
  });
}

class DefaultAbilityTooltipBuilder implements AbilityTooltipBuilder {
  static const double _authoredTicksPerSecond = 60.0;

  const DefaultAbilityTooltipBuilder({
    AbilityTagResolver tagResolver = const AbilityTagResolver(),
    StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
  }) : _tagResolver = tagResolver,
       _statusProfiles = statusProfiles;

  final AbilityTagResolver _tagResolver;
  final StatusProfileCatalog _statusProfiles;

  @override
  AbilityTooltip build(
    AbilityDef def, {
    AbilityTooltipContext ctx = const AbilityTooltipContext(),
  }) {
    final tags = _tagResolver.resolve(def);
    final badges = _buildBadges(tags);
    return AbilityTooltip(
      title: abilityDisplayName(def.id),
      description: _buildDescriptionForAbility(def, ctx),
      badges: List<String>.unmodifiable(badges),
      tags: tags,
      cooldownSeconds: _cooldownSeconds(def),
      costLines: List<AbilityCostLine>.unmodifiable(_costLines(def, ctx)),
    );
  }

  double? _cooldownSeconds(AbilityDef def) {
    if (def.cooldownTicks <= 0) return null;
    return def.cooldownTicks / _authoredTicksPerSecond;
  }

  List<AbilityCostLine> _costLines(AbilityDef def, AbilityTooltipContext ctx) {
    if (def.allowedSlots.contains(AbilitySlot.jump) && def.maxAirJumps > 0) {
      final lines = <AbilityCostLine>[];
      final firstJump = _formatCostValue(
        def.resolveCostForWeaponType(ctx.payloadWeaponType),
      );
      if (firstJump != null) {
        lines.add(
          AbilityCostLine(label: 'Cost for first jump: ', value: firstJump),
        );
      }
      final secondJump = _formatCostValue(def.airJumpCost);
      if (secondJump != null) {
        lines.add(
          AbilityCostLine(label: 'Cost for second jump: ', value: secondJump),
        );
      }
      return lines;
    }

    final lines = <AbilityCostLine>[];
    if (def.holdMode == AbilityHoldMode.holdToMaintain &&
        def.holdStaminaDrainPerSecond100 > 0) {
      lines.add(
        AbilityCostLine(
          label: 'Cost per second: ',
          value: '${_formatFixed100(def.holdStaminaDrainPerSecond100)} Stamina',
        ),
      );
    }

    final regular = _formatCostValue(
      def.resolveCostForWeaponType(ctx.payloadWeaponType),
    );
    if (regular != null) {
      lines.add(AbilityCostLine(label: 'Cost: ', value: regular));
    }
    return lines;
  }

  String? _formatCostValue(AbilityResourceCost cost) {
    final parts = <String>[];
    if (cost.healthCost100 > 0) {
      parts.add('${_formatFixed100(cost.healthCost100)} Health');
    }
    if (cost.staminaCost100 > 0) {
      parts.add('${_formatFixed100(cost.staminaCost100)} Stamina');
    }
    if (cost.manaCost100 > 0) {
      parts.add('${_formatFixed100(cost.manaCost100)} Mana');
    }
    if (parts.isEmpty) return null;
    return parts.join(' / ');
  }

  String _formatFixed100(int value100) {
    final value = (value100 / 100.0).toStringAsFixed(2);
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  List<String> _buildBadges(Set<AbilityUiTag> tags) {
    final badges = <String>[];

    void addBadge(String value) {
      if (!badges.contains(value)) badges.add(value);
    }

    for (final tag in AbilityUiTag.values) {
      if (!tags.contains(tag)) continue;
      final label = _badgeLabel(tag);
      if (label != null) addBadge(label);
    }

    return badges;
  }

  String _buildDescriptionForAbility(AbilityDef def, AbilityTooltipContext ctx) {
    switch (def.id) {
      case 'common.enemy_strike':
        return 'Tap to strike in front of you.';
      case 'common.enemy_cast':
        return 'Hold then release to cast a ranged bolt.';
      case 'eloise.bloodletter_slash':
        return 'Hold then release to perform a bleeding sword slash.';
      case 'eloise.bloodletter_cleave':
        return 'Hold then release to charge and unleash a heavy cleave.';
      case 'eloise.seeker_slash':
        return 'Tap to auto-target and slash a nearby enemy.';
      case 'eloise.riposte_guard':
        return 'Hold to guard and reduce damage by 50% while held.';
      case 'eloise.concussive_bash':
        return 'Tap to bash with your shield and stun enemies on hit.';
      case 'eloise.concussive_breaker':
        return 'Hold then release to perform a charged shield breaker.';
      case 'eloise.seeker_bash':
        return 'Tap to auto-target and bash with your shield.';
      case 'eloise.aegis_riposte':
        return 'Hold to guard and reduce damage by 50% while held.';
      case 'eloise.shield_block':
        return 'Hold to guard and reduce damage by 100% while held.';
      case 'eloise.homing_bolt':
        return ctx.selectedProjectileSpellId != null
            ? 'Tap to fire the selected spell projectile with homing.'
            : 'Tap to fire your equipped projectile with homing.';
      case 'eloise.snap_shot':
        return ctx.selectedProjectileSpellId != null
            ? 'Hold then release to fire the selected spell projectile.'
            : 'Hold then release to fire your equipped projectile.';
      case 'eloise.skewer_shot':
        return ctx.selectedProjectileSpellId != null
            ? 'Hold then release to fire a piercing line shot with the selected spell projectile.'
            : 'Hold then release to fire a piercing line shot.';
      case 'eloise.overcharge_shot':
        return 'Hold then release to charge a stronger projectile shot.';
      case 'eloise.arcane_haste':
      case 'eloise.vital_surge':
      case 'eloise.mana_infusion':
      case 'eloise.second_wind':
        return _selfStatusDescription(def, ctx);
      case 'eloise.jump':
        return 'Tap to jump.';
      case 'eloise.double_jump':
        return 'Tap to jump, then tap again in the air for a second jump.';
      case 'eloise.dash':
        return 'Tap to dash forward quickly.';
      case 'eloise.roll':
        return 'Tap to roll forward and stun enemies on contact.';
      default:
        return 'Tap to use this ability.';
    }
  }

  String _selfStatusDescription(AbilityDef def, AbilityTooltipContext ctx) {
    final inputHint = switch (def.inputLifecycle) {
      AbilityInputLifecycle.tap => 'Tap',
      AbilityInputLifecycle.holdRelease => 'Hold then release',
      AbilityInputLifecycle.holdMaintain => 'Hold',
    };
    final statusText = ctx.statusTextResolver?.describe(
      def.selfStatusProfileId,
    );
    final fallback = _describeStatusFromProfile(def.selfStatusProfileId);
    final resolved = statusText ?? fallback;
    if (resolved != null) {
      final duration = resolved.durationSeconds;
      if (duration == null) return '$inputHint to gain ${resolved.name}.';
      return '$inputHint to gain ${resolved.name} for ${duration.toStringAsFixed(1)}s.';
    }
    return '$inputHint to apply a self effect.';
  }

  StatusText? _describeStatusFromProfile(StatusProfileId id) {
    if (id == StatusProfileId.none) return null;
    final profile = _statusProfiles.get(id);
    if (profile.applications.isEmpty) return null;

    final first = profile.applications.first;
    return StatusText(
      name: _statusName(id),
      durationSeconds: first.durationSeconds,
    );
  }

  String _statusName(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.none:
        return 'Effect';
      case StatusProfileId.slowOnHit:
        return 'Slow';
      case StatusProfileId.burnOnHit:
        return 'Burn';
      case StatusProfileId.acidOnHit:
        return 'Vulnerable';
      case StatusProfileId.weakenOnHit:
        return 'Weaken';
      case StatusProfileId.drenchOnHit:
        return 'Drench';
      case StatusProfileId.silenceOnHit:
        return 'Silence';
      case StatusProfileId.meleeBleed:
        return 'Bleed';
      case StatusProfileId.stunOnHit:
        return 'Stun';
      case StatusProfileId.speedBoost:
        return 'Haste';
      case StatusProfileId.restoreHealth:
        return 'Health Regen';
      case StatusProfileId.restoreMana:
        return 'Mana Regen';
      case StatusProfileId.restoreStamina:
        return 'Stamina Regen';
    }
  }

  String? _badgeLabel(AbilityUiTag tag) {
    switch (tag) {
      case AbilityUiTag.damage:
        return 'DAMAGE';
      case AbilityUiTag.defense:
        return 'DEFENSE';
      case AbilityUiTag.dash:
        return 'DASH';
      case AbilityUiTag.jump:
        return 'JUMP';
      case AbilityUiTag.hold:
        return 'HOLD';
      case AbilityUiTag.utility:
        return 'UTILITY';
      case AbilityUiTag.crowdControl:
        return 'CONTROL';
      case AbilityUiTag.charged:
        return 'CHARGED';
      case AbilityUiTag.autoTarget:
        return 'AUTO-AIM';
      case AbilityUiTag.aimed:
        return 'AIM';
    }
  }
}
