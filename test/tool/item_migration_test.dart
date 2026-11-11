import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_id.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/stats/gear_stat_bonuses.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:runner_core/weapons/reactive_proc.dart';
import 'package:runner_core/meta/meta_service.dart';

import '../../tool/generate_backend_catalog.dart';

Map<String, Object?> stats(GearStatBonuses s) => {
  'healthBonusBp': s.healthBonusBp,
  'manaBonusBp': s.manaBonusBp,
  'staminaBonusBp': s.staminaBonusBp,
  'healthRegenBonusBp': s.healthRegenBonusBp,
  'manaRegenBonusBp': s.manaRegenBonusBp,
  'staminaRegenBonusBp': s.staminaRegenBonusBp,
  'defenseBonusBp': s.defenseBonusBp,
  'globalPowerBonusBp': s.globalPowerBonusBp,
  'globalCritChanceBonusBp': s.globalCritChanceBonusBp,
  'moveSpeedBonusBp': s.moveSpeedBonusBp,
  'cooldownReductionBp': s.cooldownReductionBp,
  'physicalResistanceBp': s.physicalResistanceBp,
  'fireResistanceBp': s.fireResistanceBp,
  'iceResistanceBp': s.iceResistanceBp,
  'waterResistanceBp': s.waterResistanceBp,
  'thunderResistanceBp': s.thunderResistanceBp,
  'acidResistanceBp': s.acidResistanceBp,
  'darkResistanceBp': s.darkResistanceBp,
  'bleedResistanceBp': s.bleedResistanceBp,
  'earthResistanceBp': s.earthResistanceBp,
  'holyResistanceBp': s.holyResistanceBp,
};
Object tuning(StatusProfileTuning t) => {
  for (final type in StatusEffectType.values)
    if (t.forType(type) case final s?)
      type.name: {
        'magnitude': s.magnitude,
        'durationSeconds': s.durationSeconds,
        'periodSeconds': s.periodSeconds,
        'scaleByDamageType': s.scaleByDamageType,
        'dotDamageType': s.dotDamageType?.name,
        'resourceType': s.resourceType?.name,
        'critBonusBp': s.critBonusBp,
        'applyOnApply': s.applyOnApply,
      },
};
Object procs(List<WeaponProc> ps) => [
  for (final p in ps)
    {
      'hook': p.hook.name,
      'profile': p.statusProfileId.name,
      'chance': p.chanceBp,
      'tuning': tuning(p.statusTuning),
    },
];
Object reactive(List<ReactiveProc> ps) => [
  for (final p in ps)
    {
      'hook': p.hook.name,
      'profile': p.statusProfileId.name,
      'chance': p.chanceBp,
      'tuning': tuning(p.statusTuning),
      'target': p.target.name,
      'threshold': p.lowHealthThresholdBp,
      'cooldown': p.internalCooldownTicks,
    },
];
Map<String, Object?> snapshot() => {
  'weapons': [
    for (final id in WeaponId.values)
      (() {
        final d = const WeaponCatalog().get(id);
        return {
          'id': id.name,
          'ordinal': id.index,
          'category': d.category.name,
          'family': d.weaponType.name,
          'damage': d.damageType.name,
          'twoHanded': d.isTwoHanded,
          'stats': stats(d.stats),
          'procs': procs(d.procs),
          'reactive': reactive(d.reactiveProcs),
        };
      })(),
  ],
  'accessories': [
    for (final id in AccessoryId.values)
      (() {
        final d = const AccessoryCatalog().get(id);
        return {
          'id': id.name,
          'ordinal': id.index,
          'slot': d.slot.name,
          'stats': stats(d.stats),
          'reactive': reactive(d.reactiveProcs),
        };
      })(),
  ],
  'books': [
    for (final id in SpellBookId.values)
      (() {
        final d = const SpellBookCatalog().get(id);
        return {
          'id': id.name,
          'ordinal': id.index,
          'family': d.weaponType.name,
          'damage': d.damageType?.name,
          'stats': stats(d.stats),
          'procs': procs(d.procs),
        };
      })(),
  ],
  'projectiles': [
    for (final id in ProjectileId.values)
      (() {
        final d = const ProjectileCatalog().tryGet(id);
        return {
          'id': id.name,
          'ordinal': id.index,
          'player': playerEquippableProjectileIds.contains(id),
          if (d != null) ...{
            'family': d.weaponType.name,
            'damage': d.damageType.name,
            'stats': stats(d.stats),
            'procs': procs(d.procs),
            'speed': d.speedUnitsPerSecond,
            'lifetime': d.lifetimeSeconds,
            'x': d.colliderSizeX,
            'y': d.colliderSizeY,
            'ballistic': d.ballistic,
            'gravity': d.gravityScale,
            'shots': d.shotCount,
            'spread': d.spreadRadians,
            'damageScale': d.damageScaleBp,
          },
        };
      })(),
  ],
  'meta': const MetaService().createNew().toJson(),
  'backend': renderBackendCatalog(),
};
void main() {
  test('migration preserves every effective field, enum ordinal, starter and backend byte', () {
    final json = '${const JsonEncoder.withIndent('  ').convert(snapshot())}\n';
    expect(
      sha256.convert(utf8.encode(json)).toString(),
      'bde5d3a8f2954cb7dbe57bbd62808b5e4f90a3a7813ff027e8e3d95a9037d61a',
      reason: 'Captured from the original catalogs before migrating. Investigate any change.',
    );
  });
}
