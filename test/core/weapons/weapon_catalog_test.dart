import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/weapons/reactive_proc.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/core/weapons/weapon_proc.dart';

void main() {
  group('weapon catalog roster values', () {
    const catalog = WeaponCatalog();

    test('plainsteel baseline stats', () {
      final def = catalog.get(WeaponId.plainsteel);
      expect(def.stats.globalPowerBonusBp, 1500);
      expect(def.stats.globalCritChanceBonusBp, 500);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.defenseBonusBp, -500);
      expect(def.procs, isEmpty);
    });

    test('sword proc roster uses one unique hook per proc item', () {
      final waspfang = catalog.get(WeaponId.waspfang);
      expect(waspfang.procs.single.hook, ProcHook.onHit);
      expect(waspfang.procs.single.statusProfileId, StatusProfileId.meleeBleed);
      expect(waspfang.procs.single.chanceBp, 3500);

      final cinderedge = catalog.get(WeaponId.cinderedge);
      expect(cinderedge.procs.single.hook, ProcHook.onCrit);
      expect(
        cinderedge.procs.single.statusProfileId,
        StatusProfileId.stunOnHit,
      );
      expect(cinderedge.procs.single.chanceBp, 2000);

      final sunlitVow = catalog.get(WeaponId.sunlitVow);
      expect(sunlitVow.procs.single.hook, ProcHook.onKill);
      expect(
        sunlitVow.procs.single.statusProfileId,
        StatusProfileId.speedBoost,
      );
      expect(sunlitVow.procs.single.chanceBp, 10000);

      final graveglass = catalog.get(WeaponId.graveglass);
      expect(graveglass.procs, isEmpty);
    });

    test('non-proc swords include dump tradeoffs', () {
      final basiliskKiss = catalog.get(WeaponId.basiliskKiss);
      expect(basiliskKiss.procs, isEmpty);
      expect(basiliskKiss.stats.globalPowerBonusBp, 1500);
      expect(basiliskKiss.stats.staminaRegenBonusBp, 1000);
      expect(basiliskKiss.stats.healthBonusBp, -1000);

      final duelistsOath = catalog.get(WeaponId.duelistsOath);
      expect(duelistsOath.procs, isEmpty);
      expect(duelistsOath.stats.globalCritChanceBonusBp, 1000);
      expect(duelistsOath.stats.staminaBonusBp, 2000);
      expect(duelistsOath.stats.manaRegenBonusBp, -500);
    });

    test('roadguard baseline shield values', () {
      final roadguard = catalog.get(WeaponId.roadguard);
      expect(roadguard.procs, isEmpty);
      expect(roadguard.reactiveProcs, isEmpty);
      expect(roadguard.stats.defenseBonusBp, 1500);
      expect(roadguard.stats.staminaBonusBp, 1500);
      expect(roadguard.stats.physicalResistanceBp, 1000);
      expect(roadguard.stats.moveSpeedBonusBp, -500);
    });

    test('thornbark and oathwall define shield reactive hooks', () {
      final thornbark = catalog.get(WeaponId.thornbark);
      final onDamaged = thornbark.reactiveProcs.singleWhere(
        (proc) => proc.hook == ReactiveProcHook.onDamaged,
      );
      expect(onDamaged.statusProfileId, StatusProfileId.meleeBleed);
      expect(onDamaged.target, ReactiveProcTarget.attacker);
      expect(onDamaged.chanceBp, 3500);

      final oathwall = catalog.get(WeaponId.oathwallRelic);
      final onLowHealth = oathwall.reactiveProcs.singleWhere(
        (proc) => proc.hook == ReactiveProcHook.onLowHealth,
      );
      expect(onLowHealth.statusProfileId, StatusProfileId.speedBoost);
      expect(onLowHealth.target, ReactiveProcTarget.self);
      expect(onLowHealth.lowHealthThresholdBp, 3000);
      expect(onLowHealth.internalCooldownTicks, 1800);

      final warbanner = catalog.get(WeaponId.warbannerGuard);
      expect(warbanner.reactiveProcs, isEmpty);
    });
  });
}
