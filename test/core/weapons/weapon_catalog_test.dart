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
      expect(def.stats.globalCritChanceBonusBp, 1000);
      expect(def.stats.staminaBonusBp, 1000);
      expect(def.stats.defenseBonusBp, -500);
      expect(def.procs, isEmpty);
    });

    test('sword proc roster uses one unique hook per proc item', () {
      final waspfang = catalog.get(WeaponId.waspfang);
      expect(waspfang.procs.single.hook, ProcHook.onHit);
      expect(waspfang.procs.single.statusProfileId, StatusProfileId.meleeBleed);
      expect(waspfang.procs.single.chanceBp, 2000);

      final cinderedge = catalog.get(WeaponId.cinderedge);
      expect(cinderedge.procs.single.hook, ProcHook.onCrit);
      expect(
        cinderedge.procs.single.statusProfileId,
        StatusProfileId.burnOnHit,
      );
      expect(cinderedge.procs.single.chanceBp, 10000);

      final sunlitVow = catalog.get(WeaponId.sunlitVow);
      expect(sunlitVow.procs.single.hook, ProcHook.onKill);
      expect(
        sunlitVow.procs.single.statusProfileId,
        StatusProfileId.focus,
      );
      expect(sunlitVow.procs.single.chanceBp, 3500);

      final stormneedle = catalog.get(WeaponId.stormneedle);
      expect(stormneedle.procs, isEmpty);
    });

    test('non-proc swords include dump tradeoffs', () {
      final plainsteel = catalog.get(WeaponId.plainsteel);
      expect(plainsteel.procs, isEmpty);
      expect(plainsteel.stats.globalPowerBonusBp, 1500);
      expect(plainsteel.stats.defenseBonusBp, -500);

      final stormneedle = catalog.get(WeaponId.stormneedle);
      expect(stormneedle.procs, isEmpty);
      expect(stormneedle.stats.globalCritChanceBonusBp, 1000);
      expect(stormneedle.stats.staminaBonusBp, 1500);
      expect(stormneedle.stats.healthBonusBp, -500);
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

    test('shield stat variants match authored values', () {
      final cinderWard = catalog.get(WeaponId.cinderWard);
      expect(cinderWard.stats.fireResistanceBp, 2500);
      expect(cinderWard.stats.defenseBonusBp, 1000);
      expect(cinderWard.stats.globalCritChanceBonusBp, -500);

      final stormAegis = catalog.get(WeaponId.stormAegis);
      expect(stormAegis.stats.thunderResistanceBp, 2500);
      expect(stormAegis.stats.staminaRegenBonusBp, 1000);
      expect(stormAegis.stats.globalCritChanceBonusBp, -500);

      final oathwall = catalog.get(WeaponId.oathwallRelic);
      expect(oathwall.stats.defenseBonusBp, 1500);
      expect(oathwall.stats.globalPowerBonusBp, -1000);
    });

    test('thornbark and oathwall define shield reactive hooks', () {
      final thornbark = catalog.get(WeaponId.thornbark);
      final onDamaged = thornbark.reactiveProcs.singleWhere(
        (proc) => proc.hook == ReactiveProcHook.onDamaged,
      );
      expect(onDamaged.statusProfileId, StatusProfileId.meleeBleed);
      expect(onDamaged.target, ReactiveProcTarget.attacker);
      expect(onDamaged.chanceBp, 3500);
      expect(thornbark.stats.defenseBonusBp, 1000);
      expect(thornbark.stats.globalPowerBonusBp, -500);

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
