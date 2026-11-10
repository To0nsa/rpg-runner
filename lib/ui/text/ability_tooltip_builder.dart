import 'package:intl/intl.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localization.dart';

import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/middleware/parry_middleware.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/projectiles/projectile_id.dart';

import 'ability_tag_resolver.dart';
import 'bounty_hunter_ability_description.dart';

import 'package:game_presentation/ability_text.dart';
import 'package:game_presentation/gear_text.dart';

import 'semantic_text.dart';

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
    this.semanticDescription = UiSemanticText.empty,
    this.badges = const <String>[],
    this.tags = const <AbilityUiTag>{},
    this.cooldownSeconds,
    this.maxDurationSeconds,
    this.costLines = const <AbilityCostLine>[],
  });

  final String title;
  final String description;
  final List<String> dynamicDescriptionValues;
  final UiSemanticText semanticDescription;
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
  const DefaultAbilityTooltipBuilder({
    required this.strings,
    required this.l10n,
    AbilityTagResolver tagResolver = const AbilityTagResolver(),
    StatusProfileCatalog statusProfiles = const StatusProfileCatalog(),
  }) : _tagResolver = tagResolver,
       _statusProfiles = statusProfiles;

  /// Bind a presenter to this build's locale; do not retain it across changes.
  factory DefaultAbilityTooltipBuilder.localized(BuildContext context) =>
      DefaultAbilityTooltipBuilder(
        strings: context.gameL10n,
        l10n: context.l10n,
      );

  factory DefaultAbilityTooltipBuilder.forLocale(Locale? locale) =>
      DefaultAbilityTooltipBuilder(
        strings: gameStringsFor(locale),
        l10n: appStringsFor(locale),
      );

  final GameLocalizations strings;
  final AppLocalizations l10n;

  final AbilityTagResolver _tagResolver;
  final StatusProfileCatalog _statusProfiles;

  @override
  AbilityTooltip build(
    AbilityDef def, {
    AbilityTooltipContext ctx = const AbilityTooltipContext(),
  }) {
    final tags = _tagResolver.resolve(def);
    final badges = _buildBadges(tags);
    final baseDescription = _descriptionWithHighlights(def, ctx);
    final impact = def.mobilityImpact;
    final breakdowns = <String>[
      if (def.baseDamageType is DamageTypeMix && def.baseDamage > 0)
        _damageBreakdown(def.baseDamage, def.baseDamageType),
      if (impact.damageType is DamageTypeMix && impact.damage100 > 0)
        _damageBreakdown(impact.damage100, impact.damageType),
    ];
    final descriptionWithHighlights = _DescriptionWithHighlights(
      description: [baseDescription.description, ...breakdowns].join(' '),
      dynamicValues: [...baseDescription.dynamicValues, ...breakdowns],
    );
    return AbilityTooltip(
      title: abilityDisplayName(def.id, strings: strings),
      description: descriptionWithHighlights.description,
      dynamicDescriptionValues: List<String>.unmodifiable(
        descriptionWithHighlights.dynamicValues,
      ),
      semanticDescription: UiSemanticText.single(
        descriptionWithHighlights.description,
        highlights: <UiSemanticHighlight>[
          for (final value in descriptionWithHighlights.dynamicValues)
            UiSemanticHighlight(value, tone: UiSemanticTone.accent),
        ],
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
    final hunterDescription = bountyHunterAbilityDescription(
      def,
      ctx.activeProjectileId,
      strings: strings,
      l10n: l10n,
    );
    if (hunterDescription != null) {
      return _DescriptionWithHighlights(description: hunterDescription);
    }
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
      case 'eloise.double_dash':
        return _description(
          message: (values) =>
              l10n.abilityDoubleDash(window: values['window']!),
          values: {
            'window': _formatOneDecimal(
              def.mobilityRecast!.windowTicks / _authoredTicksPerSecond,
            ),
          },
          dynamicKeys: ['window'],
        );
      case 'eloise.roll':
        return _concussiveRollDescription(def);
      case 'eloise.aegis_riposte':
      case 'eloise.shield_block':
        return _guardDescription(def);
      default:
        return _DescriptionWithHighlights(
          description: _notBuildDescription(def, ctx),
        );
    }
  }

  String _damageBreakdown(int amount100, DamageComposition composition) {
    final parts = composition
        .split(amount100)
        .map(
          (part) =>
              '${formatFixed100(part.amount100, strings: strings)} ${damageTypeDisplayName(part.type, strings: strings)}',
        );
    return l10n.abilityBaseDamage(parts: parts.join(' + '));
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
    final resource = def.id.startsWith('bounty_hunter.')
        ? ManaPresentation.supplies
        : ManaPresentation.mana;
    if (def.allowedSlots.contains(AbilitySlot.jump) && def.maxAirJumps > 0) {
      final lines = <AbilityCostLine>[];
      final firstJump = _formatCostValue(
        def.resolveCostForWeaponType(ctx.payloadWeaponType),
        resource,
      );
      if (firstJump != null) {
        lines.add(
          AbilityCostLine(label: l10n.abilityCostFirstJump, value: firstJump),
        );
      }
      final secondJump = _formatCostValue(def.airJumpCost, resource);
      if (secondJump != null) {
        lines.add(
          AbilityCostLine(label: l10n.abilityCostSecondJump, value: secondJump),
        );
      }
      return lines;
    }

    final lines = <AbilityCostLine>[];
    if (def.holdMode == AbilityHoldMode.holdToMaintain &&
        def.holdStaminaDrainPerSecond100 > 0) {
      lines.add(
        AbilityCostLine(
          label: l10n.abilityCostSecond,
          value: l10n.abilityCostValue(
            value: formatFixed100(
              def.holdStaminaDrainPerSecond100,
              strings: strings,
            ),
            resource: strings.statStamina,
          ),
        ),
      );
    }

    final regular = _formatCostValue(
      def.resolveCostForWeaponType(ctx.payloadWeaponType),
      resource,
    );
    if (regular != null) {
      lines.add(AbilityCostLine(label: l10n.abilityCost, value: regular));
    }
    return lines;
  }

  String? _formatCostValue(
    AbilityResourceCost cost,
    ManaPresentation resource,
  ) {
    final parts = <String>[];
    if (cost.healthCost100 > 0) {
      parts.add(
        l10n.abilityCostValue(
          value: formatFixed100(cost.healthCost100, strings: strings),
          resource: strings.statHealth,
        ),
      );
    }
    if (cost.staminaCost100 > 0) {
      parts.add(
        l10n.abilityCostValue(
          value: formatFixed100(cost.staminaCost100, strings: strings),
          resource: strings.statStamina,
        ),
      );
    }
    if (cost.manaCost100 > 0) {
      parts.add(
        l10n.abilityCostValue(
          value: formatFixed100(cost.manaCost100, strings: strings),
          resource: strings.statMana(resource: resource.name),
        ),
      );
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
      case 'grojib.strike':
      case 'grojib.strike2':
        return l10n.abilityStrike;
      case 'unoco.fire_bolt_cast':
        return l10n.abilityCast;
      case 'eloise.jump':
        return l10n.abilityJump;
      case 'eloise.double_jump':
        return l10n.abilityDoubleJump;
      default:
        return l10n.abilityUse;
    }
  }

  _DescriptionWithHighlights _seekerSlashDescription(AbilityDef def) =>
      _meleeDescription(def, aimed: false);
  _DescriptionWithHighlights _bloodletterSlashDescription(AbilityDef def) =>
      _meleeDescription(def, aimed: true);

  _DescriptionWithHighlights _bloodletterCleaveDescription(AbilityDef def) {
    final tier = def.chargeProfile!.tiers.last;
    final tap = def.chargeProfile!.tiers.first;
    final dot = _firstDotEffect(def);
    return _description(
      message: (values) => l10n.abilityCleave(
        tapDamage: values['tapDamage']!,
        chargeTime: values['chargeTime']!,
        fullDamage: values['fullDamage']!,
        crit: values['crit']!,
        status: values['status']!,
        dotDamage: values['dotDamage']!,
        duration: values['duration']!,
      ),
      values: {
        'tapDamage': formatFixed100(
          def.baseDamage * tap.damageScaleBp ~/ 10000,
          strings: strings,
        ),
        'fullDamage': formatFixed100(
          def.baseDamage * tier.damageScaleBp ~/ 10000,
          strings: strings,
        ),
        'chargeTime': _formatDecimal(
          tier.minHoldTicks60 / _authoredTicksPerSecond,
        ),
        'crit': _formatDecimal(tier.critBonusBp / 100.0),
        'status': dot.name,
        'dotDamage': formatFixed100(dot.damage100, strings: strings),
        'duration': _formatDecimal(dot.durationSeconds),
      },
      dynamicKeys: [
        'tapDamage',
        'fullDamage',
        'chargeTime',
        'crit',
        'status',
        'dotDamage',
        'duration',
      ],
    );
  }

  _DescriptionWithHighlights _snapShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    return _description(
      message: (values) => l10n.abilitySnap(
        source: values['projectileSource']!,
        projectileName: values['projectileName']!,
        damage: values['damage']!,
      ),
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage, strings: strings),
      },
      dynamicKeys: <String>['projectileName', 'damage'],
    );
  }

  _DescriptionWithHighlights _quickShotDescription(
    AbilityDef def,
    AbilityTooltipContext ctx,
  ) {
    return _description(
      message: (values) => l10n.abilityQuick(
        source: values['projectileSource']!,
        projectileName: values['projectileName']!,
        damage: values['damage']!,
      ),
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage, strings: strings),
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

    return _description(
      message: (values) => l10n.abilityOvercharge(
        source: values['projectileSource']!,
        projectileName: values['projectileName']!,
        damage: values['damage']!,
        damageBonus: values['damageBonus']!,
        critBonus: values['critBonus']!,
        chargeTime: values['chargeTime']!,
      ),
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage, strings: strings),
        'chargeTime': _formatDecimal(
          def.chargeProfile!.tiers.last.minHoldTicks60 /
              _authoredTicksPerSecond,
        ),
        'damageBonus': damageBonus,
        'critBonus': critBonus,
      },
      dynamicKeys: <String>[
        'projectileName',
        'damage',
        'chargeTime',
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
    return _description(
      message: (values) => l10n.abilitySkewer(
        source: values['projectileSource']!,
        projectileName: values['projectileName']!,
        damage: values['damage']!,
        maxHits: values['maxHits']!,
      ),
      values: <String, String>{
        'projectileSource': _projectileSourceLabel(ctx),
        'projectileName': _projectileName(ctx),
        'damage': formatFixed100(def.baseDamage, strings: strings),
        'maxHits': maxHits,
      },
      dynamicKeys: <String>['projectileName', 'damage', 'maxHits'],
    );
  }

  _DescriptionWithHighlights _dashDescription(AbilityDef def) {
    return _DescriptionWithHighlights(description: l10n.abilityDash);
  }

  _DescriptionWithHighlights _concussiveRollDescription(AbilityDef def) {
    final control = _mobilityControlEffect(def);
    return _description(
      message: (values) => l10n.abilityRoll(status: values['status']!),
      values: <String, String>{'status': control.name},
      dynamicKeys: <String>['status'],
    );
  }

  _DescriptionWithHighlights _selfStatusDescription(AbilityDef def) {
    final profile = _statusProfiles.resolve(
      def.selfStatusProfileId,
      tuning: def.selfStatusTuning,
    );
    if (profile.applications.isEmpty) {
      return _DescriptionWithHighlights(description: l10n.abilityUse);
    }

    final parts = <String>[];
    final dynamicValues = <String>[];
    for (final application in profile.applications) {
      final detail = _selfStatusEffectDescription(
        application,
        def.id.startsWith('bounty_hunter.')
            ? ManaPresentation.supplies
            : ManaPresentation.mana,
      );
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
    ManaPresentation resource,
  ) {
    final duration = _formatOneDecimal(application.durationSeconds);
    switch (application.type) {
      case StatusEffectType.haste:
        final speedBonus = _formatDecimal(application.magnitude / 100.0);
        return _DescriptionWithHighlights(
          description: l10n.abilitySelfHaste(
            speedBonus: speedBonus,
            duration: duration,
          ),
          dynamicValues: <String>[speedBonus, duration],
        );
      case StatusEffectType.damageReduction:
        final mitigation = _formatDecimal(application.magnitude / 100.0);
        return _DescriptionWithHighlights(
          description: l10n.abilitySelfWard(
            mitigation: mitigation,
            duration: duration,
          ),
          dynamicValues: <String>[mitigation, duration],
        );
      case StatusEffectType.resourceOverTime:
        final restorePct = _formatDecimal(application.magnitude / 100.0);
        final resourceLabel = switch (application.resourceType) {
          StatusResourceType.health => l10n.abilityMaxHealth,
          StatusResourceType.mana =>
            resource == ManaPresentation.supplies
                ? l10n.abilityMaxSupplies
                : l10n.abilityMaxMana,
          StatusResourceType.stamina => l10n.abilityMaxStamina,
          null => l10n.abilityMaxResource,
        };
        if (application.applyOnApply) {
          return _DescriptionWithHighlights(
            description: application.durationSeconds > 0
                ? l10n.abilityRestoreBoth(
                    restorePct: restorePct,
                    resourceLabel: resourceLabel,
                    duration: duration,
                  )
                : l10n.abilityRestoreInstant(
                    restorePct: restorePct,
                    resourceLabel: resourceLabel,
                  ),
            dynamicValues: <String>[
              restorePct,
              resourceLabel,
              if (application.durationSeconds > 0) duration,
            ],
          );
        }
        return _DescriptionWithHighlights(
          description: l10n.abilityRestore(
            restorePct: restorePct,
            resourceLabel: resourceLabel,
            duration: duration,
          ),
          dynamicValues: <String>[restorePct, resourceLabel, duration],
        );
      case StatusEffectType.offenseBuff:
        final powerBonus = _formatDecimal(application.magnitude / 100.0);
        final critBonus = _formatDecimal(
          (application.critBonusBp ?? 0) / 100.0,
        );
        return _DescriptionWithHighlights(
          description: l10n.abilitySelfFocus(
            powerBonus: powerBonus,
            critBonus: critBonus,
            duration: duration,
          ),
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
          description: l10n.abilitySelfStatus(
            statusLabel: statusLabel,
            duration: duration,
          ),
          dynamicValues: <String>[statusLabel, duration],
        );
    }
  }

  _DescriptionWithHighlights _selfPurgeDescription(AbilityDef def) {
    switch (def.selfPurgeProfileId) {
      case PurgeProfileId.none:
        return _DescriptionWithHighlights(description: l10n.abilityUse);
      case PurgeProfileId.cleanse:
        return _DescriptionWithHighlights(
          description: l10n.abilityCleanse,
          dynamicValues: <String>[
            l10n.cleanseStun,
            l10n.cleanseSilence,
            l10n.cleanseSlow,
            l10n.cleanseVulnerability,
            l10n.cleanseWeaken,
            l10n.cleanseDrench,
            l10n.cleanseDamageOverTime,
          ],
        );
    }
  }

  _DescriptionWithHighlights _meleeDescription(
    AbilityDef def, {
    required bool aimed,
  }) {
    final dot = _firstDotEffect(def);
    final damage = formatFixed100(def.baseDamage, strings: strings);
    final dotDamage = formatFixed100(dot.damage100, strings: strings);
    final duration = _formatDecimal(dot.durationSeconds);
    final hasDot = dot.damage100 > 0 && dot.durationSeconds > 0;
    return _DescriptionWithHighlights(
      description: l10n.abilityMelee(
        aim: aimed ? 'aimed' : 'nearest',
        damage: damage,
        dotKind: hasDot ? 'withDot' : 'none',
        status: dot.name,
        dotDamage: dotDamage,
        duration: duration,
      ),
      dynamicValues: [
        damage,
        if (hasDot) ...[dot.name, dotDamage, duration],
      ],
    );
  }

  _DescriptionWithHighlights _guardDescription(AbilityDef def) {
    final reduction = _formatDecimal(def.damageIgnoredBp / 100.0);
    final bonus = _formatDecimal(ParryMiddleware.defaultRiposteBonusBp / 100.0);
    return _DescriptionWithHighlights(
      description: l10n.abilityGuard(
        reduction: reduction,
        riposteKind: def.grantsRiposteOnGuardedHit ? 'withRiposte' : 'none',
        riposte: l10n.abilityRiposte,
        riposteBonus: bonus,
      ),
      dynamicValues: [
        reduction,
        if (def.grantsRiposteOnGuardedHit) ...[l10n.abilityRiposte, bonus],
      ],
    );
  }

  _DescriptionWithHighlights _description({
    required String Function(Map<String, String>) message,
    required Map<String, String> values,
    required List<String> dynamicKeys,
  }) {
    final description = message(values);
    final dynamicValues = _orderedUniqueNonEmpty(<String>[
      for (final key in dynamicKeys) values[key] ?? '',
    ]);
    return _DescriptionWithHighlights(
      description: description,
      dynamicValues: dynamicValues,
    );
  }

  _StatusDotSummary _firstDotEffect(AbilityDef def) {
    for (final proc in def.chargeProfile?.tiers.last.procs ?? def.procs) {
      if (proc.statusProfileId == StatusProfileId.none) continue;
      final profile = _statusProfiles.resolve(
        proc.statusProfileId,
        tuning: proc.statusTuning,
      );
      for (final application in profile.applications) {
        if (application.type != StatusEffectType.dot) continue;
        return _StatusDotSummary(
          name: _statusDisplayName(proc.statusProfileId),
          damage100: application.magnitude,
          durationSeconds: application.durationSeconds,
        );
      }
    }
    return _StatusDotSummary(
      name: l10n.abilityDamageOverTime,
      damage100: 0,
      durationSeconds: 0,
    );
  }

  _StatusControlSummary _mobilityControlEffect(AbilityDef def) {
    final profileId = def.mobilityImpact.statusProfileId;
    if (profileId == StatusProfileId.none) {
      return _StatusControlSummary(
        name: l10n.abilityControl,
        durationSeconds: 0,
      );
    }
    final profile = _statusProfiles.resolve(
      profileId,
      tuning: def.mobilityImpact.statusTuning,
    );
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
    return _StatusControlSummary(name: l10n.abilityControl, durationSeconds: 0);
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
        return l10n.abilityBleed;
      case StatusProfileId.burnOnHit:
        return l10n.abilityBurn;
      case StatusProfileId.acidOnHit:
        return l10n.abilityAcid;
      case StatusProfileId.stunOnHit:
        return l10n.abilityStun;
      default:
        return l10n.abilityDamageOverTime;
    }
  }

  String _projectileSourceLabel(AbilityTooltipContext ctx) {
    return ctx.payloadWeaponType == WeaponType.spell ? 'spell' : 'equipped';
  }

  String _projectileName(AbilityTooltipContext ctx) {
    final activeProjectileId = ctx.activeProjectileId;
    if (activeProjectileId == null) return '';
    return ' (${projectileDisplayName(activeProjectileId, strings: strings)})';
  }

  String _selfStatusLabel(StatusApplication application) {
    switch (application.type) {
      case StatusEffectType.haste:
        return l10n.abilityHaste;
      case StatusEffectType.damageReduction:
        return l10n.abilityWard;
      case StatusEffectType.resourceOverTime:
        switch (application.resourceType) {
          case StatusResourceType.health:
            return l10n.abilityHealthRegen;
          case StatusResourceType.mana:
            return l10n.abilityManaRegen;
          case StatusResourceType.stamina:
            return l10n.abilityStaminaRegen;
          case null:
            return l10n.abilityResourceRegen;
        }
      case StatusEffectType.offenseBuff:
        return l10n.abilityFocus;
      case StatusEffectType.dot:
      case StatusEffectType.slow:
      case StatusEffectType.stun:
      case StatusEffectType.vulnerable:
      case StatusEffectType.weaken:
      case StatusEffectType.drench:
      case StatusEffectType.silence:
        return l10n.abilityStatusEffect;
    }
  }

  String _formatOneDecimal(double value) {
    return NumberFormat('0.0', l10n.localeName).format(value);
  }

  String _formatDecimal(double value) {
    return (NumberFormat.decimalPattern(
      l10n.localeName,
    )..maximumFractionDigits = 2).format(value);
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
        return l10n.abilityBadgeDamage;
      case AbilityUiTag.defense:
        return l10n.abilityBadgeDefense;
      case AbilityUiTag.dash:
        return l10n.abilityBadgeDash;
      case AbilityUiTag.jump:
        return l10n.abilityBadgeJump;
      case AbilityUiTag.hold:
        return l10n.abilityBadgeHold;
      case AbilityUiTag.utility:
        return l10n.abilityBadgeUtility;
      case AbilityUiTag.crowdControl:
        return l10n.abilityBadgeControl;
      case AbilityUiTag.charged:
        return l10n.abilityBadgeCharged;
      case AbilityUiTag.autoTarget:
        return l10n.abilityBadgeAutoAim;
      case AbilityUiTag.aimed:
        return l10n.abilityBadgeAim;
    }
  }
}

class _StatusDotSummary {
  const _StatusDotSummary({
    required this.name,
    required this.damage100,
    required this.durationSeconds,
  });

  final String name;
  final int damage100;
  final double durationSeconds;
}

class _StatusControlSummary {
  const _StatusControlSummary({
    required this.name,
    required this.durationSeconds,
  });

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
