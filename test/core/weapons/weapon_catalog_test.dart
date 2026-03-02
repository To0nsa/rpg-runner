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
      expect(def.stats.powerBonusBp, 1000);
      expect(def.procs, isEmpty);
    });

    test('waspfang bleed pressure values', () {
      final def = catalog.get(WeaponId.waspfang);
      expect(def.stats.powerBonusBp, 1000);
      expect(def.procs.single.hook, ProcHook.onHit);
      expect(def.procs.single.statusProfileId, StatusProfileId.meleeBleed);
      expect(def.procs.single.chanceBp, 3500);
    });

    test('cinderedge crit burn values', () {
      final def = catalog.get(WeaponId.cinderedge);
      expect(def.stats.powerBonusBp, 0);
      expect(def.stats.critChanceBonusBp, 1000);
      expect(def.procs.single.hook, ProcHook.onCrit);
      expect(def.procs.single.statusProfileId, StatusProfileId.burnOnHit);
      expect(def.procs.single.chanceBp, 10000);
    });

    test('basilisk kiss anti-tank values', () {
      final def = catalog.get(WeaponId.basiliskKiss);
      expect(def.stats.powerBonusBp, 2500);
      expect(def.stats.critChanceBonusBp, -1000);
      expect(def.procs.single.hook, ProcHook.onHit);
      expect(def.procs.single.statusProfileId, StatusProfileId.acidOnHit);
      expect(def.procs.single.chanceBp, 3500);
    });

    test('frostbrand and stormneedle control values', () {
      final frostbrand = catalog.get(WeaponId.frostbrand);
      expect(frostbrand.stats.powerBonusBp, 2000);
      expect(frostbrand.procs.single.hook, ProcHook.onHit);
      expect(
        frostbrand.procs.single.statusProfileId,
        StatusProfileId.slowOnHit,
      );
      expect(frostbrand.procs.single.chanceBp, 3500);

      final stormneedle = catalog.get(WeaponId.stormneedle);
      expect(stormneedle.stats.powerBonusBp, 2000);
      expect(stormneedle.procs.single.hook, ProcHook.onHit);
      expect(
        stormneedle.procs.single.statusProfileId,
        StatusProfileId.stunOnHit,
      );
      expect(stormneedle.procs.single.chanceBp, 2000);
    });

    test('nullblade utility values', () {
      final def = catalog.get(WeaponId.nullblade);
      expect(def.stats.powerBonusBp, 1000);
      expect(def.stats.critChanceBonusBp, 1000);
      expect(def.procs.single.hook, ProcHook.onHit);
      expect(def.procs.single.statusProfileId, StatusProfileId.silenceOnHit);
      expect(def.procs.single.chanceBp, 2000);
    });

    test('sunlit vow, graveglass, duelist oath values', () {
      final sunlitVow = catalog.get(WeaponId.sunlitVow);
      expect(sunlitVow.stats.powerBonusBp, 700);
      expect(sunlitVow.stats.defenseBonusBp, 1000);
      expect(sunlitVow.procs.single.hook, ProcHook.onKill);
      expect(
        sunlitVow.procs.single.statusProfileId,
        StatusProfileId.speedBoost,
      );
      expect(sunlitVow.procs.single.chanceBp, 10000);

      final graveglass = catalog.get(WeaponId.graveglass);
      expect(graveglass.stats.globalPowerBonusBp, 3000);
      expect(graveglass.stats.defenseBonusBp, -1500);
      expect(graveglass.procs.single.hook, ProcHook.onHit);
      expect(
        graveglass.procs.single.statusProfileId,
        StatusProfileId.acidOnHit,
      );
      expect(graveglass.procs.single.chanceBp, 2000);

      final duelistsOath = catalog.get(WeaponId.duelistsOath);
      expect(duelistsOath.stats.powerBonusBp, 2000);
      expect(duelistsOath.stats.critChanceBonusBp, 1500);
      expect(duelistsOath.procs.single.hook, ProcHook.onCrit);
      expect(
        duelistsOath.procs.single.statusProfileId,
        StatusProfileId.weakenOnHit,
      );
      expect(duelistsOath.procs.single.chanceBp, 10000);
    });

    test('shield roster includes baseline and reactive profiles', () {
      final roadguard = catalog.get(WeaponId.roadguard);
      expect(roadguard.procs, isEmpty);
      expect(roadguard.reactiveProcs, isEmpty);
      expect(roadguard.stats.defenseBonusBp, 1500);
      expect(roadguard.stats.healthBonusBp, 1000);

      final thornbark = catalog.get(WeaponId.thornbark);
      expect(thornbark.reactiveProcs, hasLength(1));
      final onDamaged = thornbark.reactiveProcs.firstWhere(
        (proc) => proc.hook == ReactiveProcHook.onDamaged,
      );
      expect(onDamaged.statusProfileId, StatusProfileId.meleeBleed);
      expect(onDamaged.target, ReactiveProcTarget.attacker);
      expect(onDamaged.chanceBp, 3500);
    });

    test(
      'warbanner uses payload-based onKill and oathwall has low-health proc',
      () {
        final warbanner = catalog.get(WeaponId.warbannerGuard);
        expect(warbanner.procs, hasLength(1));
        expect(warbanner.procs.single.hook, ProcHook.onKill);
        expect(
          warbanner.procs.single.statusProfileId,
          StatusProfileId.speedBoost,
        );
        expect(warbanner.procs.single.chanceBp, 10000);

        final oathwall = catalog.get(WeaponId.oathwallRelic);
        final onLowHealth = oathwall.reactiveProcs.firstWhere(
          (proc) => proc.hook == ReactiveProcHook.onLowHealth,
        );
        expect(onLowHealth.statusProfileId, StatusProfileId.speedBoost);
        expect(onLowHealth.target, ReactiveProcTarget.self);
        expect(onLowHealth.lowHealthThresholdBp, 3000);
        expect(onLowHealth.internalCooldownTicks, 1800);
      },
    );
  });
}
