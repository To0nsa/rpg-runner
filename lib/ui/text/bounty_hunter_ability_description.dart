import 'dart:math' as math;

import 'package:game_presentation/gear_text.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';

/// Hunter-specific delivery descriptions; status details use the shared builder.
String? bountyHunterAbilityDescription(AbilityDef def, ProjectileId? weapon) {
  if (!def.id.startsWith('bounty_hunter.')) return null;
  final delivery = def.hitDelivery;
  if (delivery is BombHitDelivery) {
    final effect = switch (def.id) {
      'bounty_hunter.shrapnel_bomb' => ' Survivors bleed.',
      'bounty_hunter.fire_bomb' => ' Survivors burn.',
      'bounty_hunter.concussion_bomb' => ' Stuns susceptible enemies.',
      _ => '',
    };
    return 'Drop a bomb on the ground or in the air. It explodes '
        '${delivery.fuseTicks / 60} seconds after release, dealing '
        '${formatFixed100(def.baseDamage)} damage in a ${delivery.radius.toStringAsFixed(0)}-unit radius.'
        '$effect Solid terrain blocks the blast. Unlimited uses; cooldown only.';
  }
  if (delivery is MarkHitDelivery) {
    return 'Mark the nearest visible enemy within ${delivery.range.toStringAsFixed(0)} units '
        'for ${delivery.durationTicks / 60} seconds. Your direct attacks deal '
        '${delivery.bonusBp / 100}% more damage to that target. '
        'No target means no cost or cooldown.';
  }
  if (delivery is ProjectileHitDelivery) {
    final item = weapon == null
        ? null
        : const ProjectileCatalog().tryGet(weapon);
    final pellets = math.max(delivery.shotCount, item?.shotCount ?? 1);
    final damage = def.baseDamage * (item?.damageScaleBp ?? 10000) ~/ 10000;
    final aim = def.targetingModel == TargetingModel.homing
        ? 'Auto-aim and fire at a nearby enemy.'
        : 'Aim, then release to fire.';
    final piercing = delivery.pierce
        ? ' Each projectile can hit up to ${delivery.chainCount} enemies.'
        : '';
    final charge = def.chargeProfile != null
        ? ' Charging increases damage from 70% to 150%, adds up to 10% critical chance, and pierces two enemies at full charge. Taking damage interrupts the charge.'
        : '';
    return '$aim Deals ${formatFixed100(damage)} base damage'
        '${pellets > 1 ? ' divided across $pellets pellets' : ''}.$piercing$charge '
        'Uses regenerating Supplies.';
  }
  if (delivery is MeleeHitDelivery) {
    if (def.activeForwardSpeedX != null) {
      return 'Briefly ready your blade, then automatically rush forward while slashing. '
          "Hits each enemy in the blade's path once for ${formatFixed100(def.baseDamage)} base damage. "
          'A short recovery follows. Solid obstacles stop the lunge. '
          'You remain vulnerable throughout.';
    }
    final swings = switch (def.id) {
      'bounty_hunter.twin_cut' => 2,
      _ => 1,
    };
    return 'Strike in front of you '
        '${swings == 1 ? 'once' : '$swings times'}, dealing ${formatFixed100(def.baseDamage)} damage per swing. '
        'Each swing can hit every enemy in reach once.';
  }
  if (def.allowedSlots.contains(AbilitySlot.jump)) {
    return def.maxAirJumps > 0
        ? 'Jump, then tap again in the air for a second jump.'
        : 'Tap to jump.';
  }
  final blink = def.blinkMobility;
  if (blink != null) {
    return 'Blink forward on the ground or in the air, crossing a nearby '
        'obstacle up to ${blink.maxObstacleWidth.toStringAsFixed(0)} units wide. '
        'Requires a clear landing beyond it. A blocked exit costs nothing. '
        'Untouchable only while vanished; damage interrupts preparation and recovery.';
  }
  if (def.allowedSlots.contains(AbilitySlot.mobility)) {
    return '${switch (def.id) {
      'bounty_hunter.roll' => 'Roll forward with a low profile. Ground only.',
      'bounty_hunter.slide' => 'Slide forward with a low profile. Ground only.',
      _ => 'Dash forward on the ground or in the air.',
    }} Does not grant invulnerability.';
  }
  return null;
}
