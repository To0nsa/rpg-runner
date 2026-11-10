import 'dart:math' as math;

import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/gear_text.dart';
import 'package:intl/intl.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';

import '../l10n/app_localization.dart';

/// Hunter-specific delivery descriptions; status details use the shared builder.
String? bountyHunterAbilityDescription(
  AbilityDef def,
  ProjectileId? weapon, {
  required GameLocalizations strings,
  required AppLocalizations l10n,
}) {
  if (!def.id.startsWith('bounty_hunter.')) return null;
  final delivery = def.hitDelivery;
  if (delivery is BombHitDelivery) {
    final effect = switch (def.id) {
      'bounty_hunter.shrapnel_bomb' => 'bleed',
      'bounty_hunter.fire_bomb' => 'burn',
      'bounty_hunter.concussion_bomb' => 'stun',
      _ => 'none',
    };
    return l10n.hunterBomb(
      range: delivery.maxRange.round(),
      fuse: NumberFormat(
        '0.0',
        l10n.localeName,
      ).format(delivery.fuseTicks / 60),
      damage: formatFixed100(def.baseDamage, strings: strings),
      radius: delivery.radius.round(),
      effect: effect,
    );
  }
  if (delivery is MarkHitDelivery) {
    return l10n.hunterMark(
      range: delivery.range.round(),
      duration: delivery.durationTicks / 60,
      bonus: delivery.bonusBp / 100,
    );
  }
  if (delivery is ProjectileHitDelivery) {
    final item = weapon == null
        ? null
        : const ProjectileCatalog().tryGet(weapon);
    final pellets = math.max(delivery.shotCount, item?.shotCount ?? 1);
    final damage = def.baseDamage * (item?.damageScaleBp ?? 10000) ~/ 10000;
    final tiers = def.chargeProfile?.tiers;
    return l10n.hunterShot(
      aim: def.targetingModel == TargetingModel.homing ? 'automatic' : 'aimed',
      damage: formatFixed100(damage, strings: strings),
      pellets: pellets,
      piercing: delivery.pierce ? 'yes' : 'no',
      maxHits: delivery.chainCount,
      charged: tiers != null ? 'yes' : 'no',
      minDamage: (tiers?.first.damageScaleBp ?? 10000) / 100,
      maxDamage: (tiers?.last.damageScaleBp ?? 10000) / 100,
      crit: (tiers?.last.critBonusBp ?? 0) / 100,
      chargeHits: tiers?.last.maxPierceHits ?? delivery.chainCount,
    );
  }
  if (delivery is MeleeHitDelivery) {
    final damage = formatFixed100(def.baseDamage, strings: strings);
    if (def.activeForwardSpeedX != null) {
      return l10n.hunterLunge(damage: damage);
    }
    final swings = switch (def.id) {
      'bounty_hunter.twin_cut' => 2,
      _ => 1,
    };
    return l10n.hunterMelee(swings: swings, damage: damage);
  }
  if (def.allowedSlots.contains(AbilitySlot.jump)) {
    return def.maxAirJumps > 0 ? l10n.hunterDoubleJump : l10n.abilityJump;
  }
  final blink = def.blinkMobility;
  if (blink != null) {
    return l10n.hunterBlink(width: blink.maxObstacleWidth.round());
  }
  if (def.allowedSlots.contains(AbilitySlot.mobility)) {
    final recast = def.mobilityRecast;
    return recast != null
        ? l10n.hunterDoubleDash(
            window: NumberFormat(
              '0.0',
              l10n.localeName,
            ).format(recast.windowTicks / 60),
          )
        : l10n.hunterDash;
  }
  return null;
}
