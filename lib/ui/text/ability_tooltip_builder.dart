import '../../core/abilities/ability_def.dart';
import '../../core/combat/status/status.dart';
import '../../core/projectiles/projectile_id.dart';
import 'ability_tag_resolver.dart';
import 'ability_text.dart';

class AbilityCostLine {
  const AbilityCostLine({required this.label, required this.value});

  final String label;
  final String value;
}

class AbilityTooltipContext {
  const AbilityTooltipContext({
    this.selectedProjectileSpellId,
    this.payloadWeaponType,
  });

  final ProjectileId? selectedProjectileSpellId;
  final WeaponType? payloadWeaponType;
}

class AbilityTooltip {
  const AbilityTooltip({
    required this.title,
    required this.description,
    this.dynamicDescriptionValues = const <String>[],
    this.badges = const <String>[],
    this.tags = const <AbilityUiTag>{},
    this.cooldownSeconds,
    this.costLines = const <AbilityCostLine>[],
  });

  final String title;
  final String description;
  final List<String> dynamicDescriptionValues;
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
    final descriptionWithHighlights = _descriptionWithHighlights(def, ctx);
    return AbilityTooltip(
      title: abilityDisplayName(def.id),
      description: descriptionWithHighlights.description,
      dynamicDescriptionValues: List<String>.unmodifiable(
        descriptionWithHighlights.dynamicValues,
      ),
      badges: List<String>.unmodifiable(badges),
      tags: tags,
      cooldownSeconds: _cooldownSeconds(def),
      costLines: List<AbilityCostLine>.unmodifiable(_costLines(def, ctx)),
    );
  }

  _DescriptionWithHighlights _descriptionWithHighlights(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    switch (def.id) {
      case 'eloise.bloodletter_slash':
        return _bloodletterSlashDescription(def);
      case 'eloise.seeker_slash':
        return _seekerSlashDescription(def);
      case 'eloise.bloodletter_cleave':
        return _bloodletterCleaveDescription(def);
      default:
        return _DescriptionWithHighlights(
          description: _buildDescriptionForAbility(def, ctx),
        );
    }
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

  String _buildDescriptionForAbility(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
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
        return 'Tap to gain Haste for 5.0s.';
      case 'eloise.vital_surge':
        return 'Tap to gain Health Regen for 5.0s.';
      case 'eloise.mana_infusion':
        return 'Tap to gain Mana Regen for 5.0s.';
      case 'eloise.second_wind':
        return 'Tap to gain Stamina Regen for 5.0s.';
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

  _DescriptionWithHighlights _seekerSlashDescription(AbilityDef def) {
    final damage = _formatFixed100(def.baseDamage);
    final dot = _firstDotEffect(def);
    final statusName = dot.name;
    final dotDamage = _formatFixed100(dot.damage100);
    final dotDuration = _formatDecimal(dot.durationSeconds);
    return _DescriptionWithHighlights(
      description:
          'Launch an attack that deals $damage damage to the closest enemy and all those who are in the attack reach causing $statusName that deals $dotDamage damage per second for $dotDuration seconds.',
      dynamicValues: _orderedUniqueNonEmpty(<String>[
        damage,
        statusName,
        dotDamage,
        dotDuration,
      ]),
    );
  }

  _DescriptionWithHighlights _bloodletterSlashDescription(AbilityDef def) {
    final damage = _formatFixed100(def.baseDamage);
    final dot = _firstDotEffect(def);
    final statusName = dot.name;
    final dotDamage = _formatFixed100(dot.damage100);
    final dotDuration = _formatDecimal(dot.durationSeconds);
    return _DescriptionWithHighlights(
      description:
          'Unleash a sword slash that deals $damage damage to enemies in aiming direction and in the attack reach. It causes $statusName, dealing $dotDamage damage per second for $dotDuration seconds.',
      dynamicValues: _orderedUniqueNonEmpty(<String>[
        damage,
        statusName,
        dotDamage,
        dotDuration,
      ]),
    );
  }

  _DescriptionWithHighlights _bloodletterCleaveDescription(AbilityDef def) {
    final damage = _formatFixed100(def.baseDamage);
    final dot = _firstDotEffect(def);
    final charge = _maxChargeBonuses(def);
    final statusName = dot.name;
    final dotDamage = _formatFixed100(dot.damage100);
    final dotDuration = _formatDecimal(dot.durationSeconds);
    final damageBonus = _formatDecimal(charge.damageBonusBp / 100.0);
    final critBonus = _formatDecimal(charge.critBonusBp / 100.0);

    return _DescriptionWithHighlights(
      description:
          'Unleash a powerful cleaving attack that deals $damage damage to all enemies in aiming direction and in the attack reach. It causes $statusName, dealing $dotDamage damage per second for $dotDuration seconds. Charging increases damage (up to +$damageBonus%) and critical chance (up to +$critBonus%). This attack can be interrupted by taking damage.',
      dynamicValues: _orderedUniqueNonEmpty(<String>[
        damage,
        statusName,
        dotDamage,
        dotDuration,
        damageBonus,
        critBonus,
      ]),
    );
  }

  _StatusDotSummary _firstDotEffect(AbilityDef def) {
    for (final proc in def.procs) {
      if (proc.statusProfileId == StatusProfileId.none) continue;
      final profile = _statusProfiles.get(proc.statusProfileId);
      for (final application in profile.applications) {
        if (application.type != StatusEffectType.dot) continue;
        return _StatusDotSummary(
          name: _statusDisplayName(proc.statusProfileId),
          damage100: application.magnitude,
          durationSeconds: application.durationSeconds,
        );
      }
    }
    return const _StatusDotSummary.none();
  }

  _ChargeBonusSummary _maxChargeBonuses(AbilityDef def) {
    final tiers = def.chargeProfile?.tiers;
    if (tiers == null || tiers.isEmpty) {
      return const _ChargeBonusSummary.none();
    }

    var maxDamageScaleBp = tiers.first.damageScaleBp;
    var maxCritBonusBp = tiers.first.critBonusBp;
    for (final tier in tiers.skip(1)) {
      if (tier.damageScaleBp > maxDamageScaleBp) {
        maxDamageScaleBp = tier.damageScaleBp;
      }
      if (tier.critBonusBp > maxCritBonusBp) {
        maxCritBonusBp = tier.critBonusBp;
      }
    }

    final damageBonusBp = maxDamageScaleBp > 10000
        ? maxDamageScaleBp - 10000
        : 0;
    final critBonusBp = maxCritBonusBp > 0 ? maxCritBonusBp : 0;
    return _ChargeBonusSummary(
      damageBonusBp: damageBonusBp,
      critBonusBp: critBonusBp,
    );
  }

  String _statusDisplayName(StatusProfileId id) {
    switch (id) {
      case StatusProfileId.meleeBleed:
        return 'Bleed';
      case StatusProfileId.burnOnHit:
        return 'Burn';
      case StatusProfileId.acidOnHit:
        return 'Acid';
      default:
        return 'damage over time';
    }
  }

  String _formatDecimal(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  List<String> _orderedUniqueNonEmpty(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      if (value.isEmpty || !seen.add(value)) continue;
      result.add(value);
    }
    return result;
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

class _StatusDotSummary {
  const _StatusDotSummary({
    required this.name,
    required this.damage100,
    required this.durationSeconds,
  });

  const _StatusDotSummary.none()
    : name = 'damage over time',
      damage100 = 0,
      durationSeconds = 0;

  final String name;
  final int damage100;
  final double durationSeconds;
}

class _ChargeBonusSummary {
  const _ChargeBonusSummary({
    required this.damageBonusBp,
    required this.critBonusBp,
  });

  const _ChargeBonusSummary.none() : damageBonusBp = 0, critBonusBp = 0;

  final int damageBonusBp;
  final int critBonusBp;
}

class _DescriptionWithHighlights {
  const _DescriptionWithHighlights({
    required this.description,
    this.dynamicValues = const <String>[],
  });

  final String description;
  final List<String> dynamicValues;
}
