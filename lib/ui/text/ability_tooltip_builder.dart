import '../../core/abilities/ability_def.dart';
import '../../core/combat/middleware/parry_middleware.dart';
import '../../core/combat/status/status.dart';
import '../../core/projectiles/projectile_id.dart';
import 'ability_tag_resolver.dart';
import 'ability_text.dart';
import 'gear_text.dart';

class AbilityCostLine {
  const AbilityCostLine({required this.label, required this.value});

  final String label;
  final String value;
}

class AbilityTooltipContext {
  const AbilityTooltipContext({
    this.activeProjectileId,
    this.payloadWeaponType,
  });

  /// The projectile that will actually be fired — either a spell projectile
  /// (e.g. Fire Bolt) or a physical throwing weapon (e.g. Throwing Knife).
  final ProjectileId? activeProjectileId;
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
    this.maxDurationSeconds,
    this.costLines = const <AbilityCostLine>[],
  });

  final String title;
  final String description;
  final List<String> dynamicDescriptionValues;
  final List<String> badges;
  final Set<AbilityUiTag> tags;
  final double? cooldownSeconds;
  final double? maxDurationSeconds;
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
  static const String _templateMeleeDamage =
      '{action} that deals {damage} damage to {targets}.';
  static const String _templateMeleeDot =
      '{action} that deals {damage} damage to {targets}. '
      'It causes {status}, dealing {dotDamage} damage per second for {dotDuration} seconds.';
  static const String _templateMeleeControl =
      '{action} that deals {damage} damage to {targets}. '
      'It causes {status} for {duration} seconds.';
  static const String _templateChargedBonus =
      ' Charging increases damage (up to +{damageBonus}%) '
      'and critical chance (up to +{critBonus}%).';
  static const String _templateInterruptible =
      ' This attack can be interrupted by taking damage.';
  static const String _templateGuard =
      'Keep your guard up and reduce incoming damage by {reduction}% while held.';
  static const String _templateRiposteGrant =
      ' Guarded hits grant {riposte}, empowering your next melee hit by +{riposteBonus}% damage.';
  static const String _templateSnapShot =
      'Fire {projectileSource}{projectileName}, it deals {damage} damage to the closest enemy.';
  static const String _templateQuickShot =
      'Aim and fire {projectileSource}{projectileName}. It deals {damage} damage to a single target.';
  static const String _templateOverchargeShot =
      'Charge and release {projectileSource}{projectileName}. '
      'It deals {damage} damage to a single target.';
  static const String _templateSkewerShot =
      'Fire {projectileSource}{projectileName}, piercing through enemies in its path. '
      'It deals {damage} damage and can hit up to {maxHits} enemies.';
  static const String _riposteLabel = 'Riposte';
  static const String _targetClosestAndReach =
      'the closest enemy and all those who are in the attack reach';
  static const String _targetAimingDirectionAndReach =
      'enemies in aiming direction and in the attack reach';

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
      maxDurationSeconds: _maxDurationSeconds(def),
      costLines: List<AbilityCostLine>.unmodifiable(_costLines(def, ctx)),
    );
  }

  _DescriptionWithHighlights _descriptionWithHighlights(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    if (def.selfPurgeProfileId != PurgeProfileId.none) {
      return _selfPurgeDescription(def);
    }
    if (def.selfStatusProfileId != StatusProfileId.none) {
      return _selfStatusDescription(def);
    }
    switch (def.id) {
      case 'eloise.bloodletter_slash':
        return _bloodletterSlashDescription(def);
      case 'eloise.seeker_slash':
        return _seekerSlashDescription(def);
      case 'eloise.bloodletter_cleave':
        return _bloodletterCleaveDescription(def);
      case 'eloise.seeker_bash':
        return _seekerBashDescription(def);
      case 'eloise.concussive_bash':
        return _concussiveBashDescription(def);
      case 'eloise.concussive_breaker':
        return _concussiveBreakerDescription(def);
      case 'eloise.snap_shot':
        return _snapShotDescription(def, ctx);
      case 'eloise.quick_shot':
        return _quickShotDescription(def, ctx);
      case 'eloise.overcharge_shot':
        return _overchargeShotDescription(def, ctx);
      case 'eloise.skewer_shot':
        return _skewerShotDescription(def, ctx);
      case 'eloise.dash':
        return _dashDescription(def);
      case 'eloise.roll':
        return _concussiveRollDescription(def);
      case 'eloise.riposte_guard':
      case 'eloise.aegis_riposte':
      case 'eloise.shield_block':
        return _guardDescription(def);
      default:
        return _DescriptionWithHighlights(
          description: _notBuildDescription(def, ctx),
        );
    }
  }

  double? _cooldownSeconds(AbilityDef def) {
    if (def.cooldownTicks <= 0) return null;
    return def.cooldownTicks / _authoredTicksPerSecond;
  }

  double? _maxDurationSeconds(AbilityDef def) {
    if (def.holdMode != AbilityHoldMode.holdToMaintain) return null;
    if (def.activeTicks <= 0) return null;
    return def.activeTicks / _authoredTicksPerSecond;
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
          value: '${formatFixed100(def.holdStaminaDrainPerSecond100)} Stamina',
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
      parts.add('${formatFixed100(cost.healthCost100)} Health');
    }
    if (cost.staminaCost100 > 0) {
      parts.add('${formatFixed100(cost.staminaCost100)} Stamina');
    }
    if (cost.manaCost100 > 0) {
      parts.add('${formatFixed100(cost.manaCost100)} Mana');
    }
    if (parts.isEmpty) return null;
    return parts.join(' / ');
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

  String _notBuildDescription(AbilityDef def, AbilityTooltipContext ctx) {
    switch (def.id) {
      case 'common.enemy_strike':
        return 'Tap to strike in front of you.';
      case 'common.enemy_cast':
        return 'Hold then release to cast a ranged bolt.';
      case 'eloise.jump':
        return 'Tap to jump.';
      case 'eloise.double_jump':
        return 'Tap to jump, then tap again in the air for a second jump.';
      default:
        return 'Tap to use this ability.';
    }
  }

  _DescriptionWithHighlights _seekerSlashDescription(AbilityDef def) {
    return _buildMeleeDescription(
      def: def,
      action: 'Launch an attack',
      damage: formatFixed100(def.baseDamage),
      targets: _targetClosestAndReach,
    );
  }

  _DescriptionWithHighlights _bloodletterSlashDescription(AbilityDef def) {
    return _buildMeleeDescription(
      def: def,
      action: 'Unleash a sword slash',
      damage: formatFixed100(def.baseDamage),
      targets: _targetAimingDirectionAndReach,
    );
  }

  _DescriptionWithHighlights _bloodletterCleaveDescription(AbilityDef def) {
    final damage = formatFixed100(def.baseDamage);
    final dot = _firstDotEffect(def);
    final charge = _maxChargeBonuses(def);
    final damageBonus = _formatDecimal(charge.damageBonusBp / 100.0);
    final critBonus = _formatDecimal(charge.critBonusBp / 100.0);

    return _buildMeleeDotDescription(
      action: 'Unleash a powerful cleaving attack',
      damage: damage,
      targets: _targetAimingDirectionAndReach,
      dot: dot,
      damageBonus: damageBonus,
      critBonus: critBonus,
      includeInterruptibleLine: true,
    );
  }

  _DescriptionWithHighlights _seekerBashDescription(AbilityDef def) {
    final damage = formatFixed100(def.baseDamage);
    final control = _firstControlEffect(def);
    return _descriptionFromTemplate(
      template: _templateMeleeControl,
      values: <String, String>{
        'action': 'Strike with a shield bash',
        'damage': damage,
        'targets': _targetClosestAndReach,
        'status': control.name,
        'duration': _formatDecimal(control.durationSeconds),
      },
      dynamicKeys: <String>['damage', 'status', 'duration'],
    );
  }

  _DescriptionWithHighlights _concussiveBashDescription(AbilityDef def) {
    final damage = formatFixed100(def.baseDamage);
    final control = _firstControlEffect(def);
    return _descriptionFromTemplate(
      template: _templateMeleeControl,
      values: <String, String>{
        'action': 'Perform a shield bash',
        'damage': damage,
        'targets': _targetAimingDirectionAndReach,
        'status': control.name,
        'duration': _formatDecimal(control.durationSeconds),
      },
      dynamicKeys: <String>['damage', 'status', 'duration'],
    );
  }

  _DescriptionWithHighlights _concussiveBreakerDescription(AbilityDef def) {
    final damage = formatFixed100(def.baseDamage);
    final control = _firstControlEffect(def);
    final charge = _maxChargeBonuses(def);
    final damageBonus = _formatDecimal(charge.damageBonusBp / 100.0);
    final critBonus = _formatDecimal(charge.critBonusBp / 100.0);

    return _descriptionFromTemplate(
      template:
          _templateMeleeControl +
          _templateChargedBonus +
          _templateInterruptible,
      values: <String, String>{
        'action': 'Launch a heavy shield breaker',
        'damage': damage,
        'targets': _targetAimingDirectionAndReach,
        'status': control.name,
        'duration': _formatDecimal(control.durationSeconds),
        'damageBonus': damageBonus,
        'critBonus': critBonus,
      },
      dynamicKeys: <String>[
        'damage',
        'status',
        'duration',
        'damageBonus',
        'critBonus',
      ],
    );
  }

  _DescriptionWithHighlights _snapShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    return _descriptionFromTemplate(
      template: _templateSnapShot,
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage),
      },
      dynamicKeys: <String>['projectileName', 'damage'],
    );
  }

  _DescriptionWithHighlights _quickShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    return _descriptionFromTemplate(
      template: _templateQuickShot,
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage),
      },
      dynamicKeys: <String>['projectileName', 'damage'],
    );
  }

  _DescriptionWithHighlights _overchargeShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    final charge = _maxChargeBonuses(def);
    final damageBonus = _formatDecimal(charge.damageBonusBp / 100.0);
    final critBonus = _formatDecimal(charge.critBonusBp / 100.0);

    return _descriptionFromTemplate(
      template:
          _templateOverchargeShot +
          _templateChargedBonus +
          _templateInterruptible,
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage),
        'damageBonus': damageBonus,
        'critBonus': critBonus,
      },
      dynamicKeys: <String>[
        'projectileName',
        'damage',
        'damageBonus',
        'critBonus',
      ],
    );
  }

  _DescriptionWithHighlights _skewerShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    final hitDelivery = def.hitDelivery;
    final maxHits = hitDelivery is ProjectileHitDelivery
        ? hitDelivery.chainCount.toString()
        : '?';
    return _descriptionFromTemplate(
      template: _templateSkewerShot,
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage),
        'maxHits': maxHits,
      },
      dynamicKeys: <String>['projectileName', 'damage', 'maxHits'],
    );
  }

  _DescriptionWithHighlights _dashDescription(AbilityDef def) {
    return const _DescriptionWithHighlights(
      description: 'Dash forward quickly.',
    );
  }

  _DescriptionWithHighlights _concussiveRollDescription(AbilityDef def) {
    final control = _mobilityControlEffect(def);
    return _descriptionFromTemplate(
      template:
          'Perform a concussive roll. Enemies hit are affected by {status}.',
      values: <String, String>{'status': control.name},
      dynamicKeys: <String>['status'],
    );
  }

  _DescriptionWithHighlights _selfStatusDescription(AbilityDef def) {
    final profile = _statusProfiles.get(def.selfStatusProfileId);
    if (profile.applications.isEmpty) {
      return const _DescriptionWithHighlights(
        description: 'Tap to use this ability.',
      );
    }

    final parts = <String>[];
    final dynamicValues = <String>[];
    for (final application in profile.applications) {
      final detail = _selfStatusEffectDescription(application);
      parts.add(detail.description);
      dynamicValues.addAll(detail.dynamicValues);
    }

    return _DescriptionWithHighlights(
      description: parts.join(' '),
      dynamicValues: _orderedUniqueNonEmpty(dynamicValues),
    );
  }

  _DescriptionWithHighlights _selfStatusEffectDescription(
    StatusApplication application,
  ) {
    final duration = _formatOneDecimal(application.durationSeconds);
    switch (application.type) {
      case StatusEffectType.haste:
        final speedBonus = _formatDecimal(application.magnitude / 100.0);
        return _DescriptionWithHighlights(
          description:
              'Increase move speed by $speedBonus% for $duration seconds.',
          dynamicValues: <String>[speedBonus, duration],
        );
      case StatusEffectType.damageReduction:
        final mitigation = _formatDecimal(application.magnitude / 100.0);
        return _DescriptionWithHighlights(
          description:
              'Reduce direct-hit damage by $mitigation% and cancel damage-over-time effects for $duration seconds.',
          dynamicValues: <String>[mitigation, duration],
        );
      case StatusEffectType.resourceOverTime:
        final restorePct = _formatDecimal(application.magnitude / 100.0);
        final resourceLabel = switch (application.resourceType) {
          StatusResourceType.health => 'max Health',
          StatusResourceType.mana => 'max Mana',
          StatusResourceType.stamina => 'max Stamina',
          null => 'max resource',
        };
        return _DescriptionWithHighlights(
          description:
              'Restore $restorePct% of $resourceLabel over $duration seconds.',
          dynamicValues: <String>[restorePct, resourceLabel, duration],
        );
      case StatusEffectType.offenseBuff:
        final powerBonus = _formatDecimal(application.magnitude / 100.0);
        final critBonus = _formatDecimal(
          (application.critBonusBp ?? 0) / 100.0,
        );
        return _DescriptionWithHighlights(
          description:
              'Increase power by $powerBonus% and critical chance by $critBonus% for $duration seconds.',
          dynamicValues: <String>[powerBonus, critBonus, duration],
        );
      case StatusEffectType.dot:
      case StatusEffectType.slow:
      case StatusEffectType.stun:
      case StatusEffectType.vulnerable:
      case StatusEffectType.weaken:
      case StatusEffectType.drench:
      case StatusEffectType.silence:
        final statusLabel = _selfStatusLabel(application);
        return _DescriptionWithHighlights(
          description: 'Apply $statusLabel for $duration seconds.',
          dynamicValues: <String>[statusLabel, duration],
        );
    }
  }

  _DescriptionWithHighlights _selfPurgeDescription(AbilityDef def) {
    switch (def.selfPurgeProfileId) {
      case PurgeProfileId.none:
        return const _DescriptionWithHighlights(
          description: 'Tap to use this ability.',
        );
      case PurgeProfileId.cleanse:
        return const _DescriptionWithHighlights(
          description:
              'Cleanse all active debuffs, including stun, silence, slow, vulnerability, weaken, drench, and damage-over-time effects.',
          dynamicValues: <String>[
            'stun',
            'silence',
            'slow',
            'vulnerability',
            'weaken',
            'drench',
            'damage-over-time',
          ],
        );
    }
  }

  _DescriptionWithHighlights _buildMeleeDotDescription({
    required String action,
    required String damage,
    required String targets,
    required _StatusDotSummary dot,
    String? damageBonus,
    String? critBonus,
    bool includeInterruptibleLine = false,
  }) {
    final values = <String, String>{
      'action': action,
      'damage': damage,
      'targets': targets,
      'status': dot.name,
      'dotDamage': formatFixed100(dot.damage100),
      'dotDuration': _formatDecimal(dot.durationSeconds),
      if (damageBonus != null) 'damageBonus': damageBonus,
      if (critBonus != null) 'critBonus': critBonus,
    };

    var template = _templateMeleeDot;
    final dynamicKeys = <String>[
      'damage',
      'status',
      'dotDamage',
      'dotDuration',
    ];

    if (damageBonus != null && critBonus != null) {
      template += _templateChargedBonus;
      dynamicKeys
        ..add('damageBonus')
        ..add('critBonus');
    }
    if (includeInterruptibleLine) {
      template += _templateInterruptible;
    }

    return _descriptionFromTemplate(
      template: template,
      values: values,
      dynamicKeys: dynamicKeys,
    );
  }

  _DescriptionWithHighlights _buildMeleeDescription({
    required AbilityDef def,
    required String action,
    required String damage,
    required String targets,
  }) {
    final dot = _firstDotEffect(def);
    if (dot.damage100 <= 0 || dot.durationSeconds <= 0) {
      return _descriptionFromTemplate(
        template: _templateMeleeDamage,
        values: <String, String>{
          'action': action,
          'damage': damage,
          'targets': targets,
        },
        dynamicKeys: <String>['damage'],
      );
    }
    return _buildMeleeDotDescription(
      action: action,
      damage: damage,
      targets: targets,
      dot: dot,
    );
  }

  _DescriptionWithHighlights _guardDescription(AbilityDef def) {
    final reduction = _formatDecimal(def.damageIgnoredBp / 100.0);
    final riposteBonus = _formatDecimal(
      ParryMiddleware.defaultRiposteBonusBp / 100.0,
    );
    final values = <String, String>{
      'reduction': reduction,
      if (def.grantsRiposteOnGuardedHit) 'riposte': _riposteLabel,
      if (def.grantsRiposteOnGuardedHit) 'riposteBonus': riposteBonus,
    };
    var template = _templateGuard;
    final dynamicKeys = <String>['reduction'];
    if (def.grantsRiposteOnGuardedHit) {
      template += _templateRiposteGrant;
      dynamicKeys
        ..add('riposte')
        ..add('riposteBonus');
    }
    return _descriptionFromTemplate(
      template: template,
      values: values,
      dynamicKeys: dynamicKeys,
    );
  }

  _DescriptionWithHighlights _descriptionFromTemplate({
    required String template,
    required Map<String, String> values,
    required List<String> dynamicKeys,
  }) {
    var description = template;
    for (final entry in values.entries) {
      description = description.replaceAll('{${entry.key}}', entry.value);
    }
    final dynamicValues = _orderedUniqueNonEmpty(<String>[
      for (final key in dynamicKeys) values[key] ?? '',
    ]);
    return _DescriptionWithHighlights(
      description: description,
      dynamicValues: dynamicValues,
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

  _StatusControlSummary _firstControlEffect(AbilityDef def) {
    for (final proc in def.procs) {
      if (proc.statusProfileId == StatusProfileId.none) continue;
      final profile = _statusProfiles.get(proc.statusProfileId);
      for (final application in profile.applications) {
        switch (application.type) {
          case StatusEffectType.stun:
          case StatusEffectType.slow:
          case StatusEffectType.silence:
          case StatusEffectType.weaken:
          case StatusEffectType.vulnerable:
          case StatusEffectType.drench:
            return _StatusControlSummary(
              name: _statusDisplayName(proc.statusProfileId),
              durationSeconds: application.durationSeconds,
            );
          case StatusEffectType.dot:
          case StatusEffectType.haste:
          case StatusEffectType.damageReduction:
          case StatusEffectType.resourceOverTime:
          case StatusEffectType.offenseBuff:
            continue;
        }
      }
    }
    return const _StatusControlSummary.none();
  }

  _StatusControlSummary _mobilityControlEffect(AbilityDef def) {
    final profileId = def.mobilityImpact.statusProfileId;
    if (profileId == StatusProfileId.none) {
      return const _StatusControlSummary.none();
    }
    final profile = _statusProfiles.get(profileId);
    for (final application in profile.applications) {
      switch (application.type) {
        case StatusEffectType.stun:
        case StatusEffectType.slow:
        case StatusEffectType.silence:
        case StatusEffectType.weaken:
        case StatusEffectType.vulnerable:
        case StatusEffectType.drench:
          return _StatusControlSummary(
            name: _statusDisplayName(profileId),
            durationSeconds: application.durationSeconds,
          );
        case StatusEffectType.dot:
        case StatusEffectType.haste:
        case StatusEffectType.damageReduction:
        case StatusEffectType.resourceOverTime:
        case StatusEffectType.offenseBuff:
          continue;
      }
    }
    return const _StatusControlSummary.none();
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
      case StatusProfileId.stunOnHit:
        return 'Stun';
      default:
        return 'damage over time';
    }
  }

  String _projectileSourceLabel(AbilityTooltipContext ctx) {
    return ctx.payloadWeaponType == WeaponType.spell
        ? 'the selected spell projectile'
        : 'your equipped projectile';
  }

  String _projectileName(AbilityTooltipContext ctx) {
    final activeProjectileId = ctx.activeProjectileId;
    if (activeProjectileId == null) return '';
    return ' (${projectileDisplayName(activeProjectileId)})';
  }

  String _selfStatusLabel(StatusApplication application) {
    switch (application.type) {
      case StatusEffectType.haste:
        return 'Haste';
      case StatusEffectType.damageReduction:
        return 'Arcane Ward';
      case StatusEffectType.resourceOverTime:
        switch (application.resourceType) {
          case StatusResourceType.health:
            return 'Health Regen';
          case StatusResourceType.mana:
            return 'Mana Regen';
          case StatusResourceType.stamina:
            return 'Stamina Regen';
          case null:
            return 'Resource Regen';
        }
      case StatusEffectType.offenseBuff:
        return 'Focus';
      case StatusEffectType.dot:
      case StatusEffectType.slow:
      case StatusEffectType.stun:
      case StatusEffectType.vulnerable:
      case StatusEffectType.weaken:
      case StatusEffectType.drench:
      case StatusEffectType.silence:
        return 'Status Effect';
    }
  }

  String _formatOneDecimal(double value) {
    return value.toStringAsFixed(1);
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

class _StatusControlSummary {
  const _StatusControlSummary({
    required this.name,
    required this.durationSeconds,
  });

  const _StatusControlSummary.none() : name = 'Control', durationSeconds = 0;

  final String name;
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
