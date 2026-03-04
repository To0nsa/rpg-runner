import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';
import 'package:rpg_runner/core/weapons/reactive_proc.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_category.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';
import 'package:rpg_runner/core/weapons/weapon_proc.dart';

void main() {
  group('gear authoring constraints', () {
    test('weapon catalog respects slot identity and proc-family rules', () {
      const catalog = WeaponCatalog();
      final usedProcIdentities = <String>{};
      final primaryIdentity = <String>{};
      final offhandIdentity = <String>{};

      for (final id in WeaponId.values) {
        final def = catalog.get(id);
        final stats = _statMap(def.stats);
        final outgoingCount = def.procs.length;
        final reactiveCount = def.reactiveProcs.length;
        final positiveCount = _positiveStatCount(stats);
        final negativeCount = _negativeStatCount(stats);

        _expectProcClusterConstraints(
          id: id,
          procs: def.procs,
          reactiveProcs: def.reactiveProcs,
        );

        for (final entry in stats.entries) {
          final value = entry.value;
          if (value == 0) continue;
          expect(value.abs() >= 500, isTrue, reason: '$id ${entry.key}');
          expect(value % 500 == 0, isTrue, reason: '$id ${entry.key}: $value');
          expect(
            _isWithinStatBounds(entry.key, value),
            isTrue,
            reason: '$id ${entry.key}: $value',
          );
        }

        if (def.category == WeaponCategory.primary) {
          for (final entry in stats.entries) {
            final value = entry.value;
            if (value > 0) {
              expect(
                _primaryPositive.contains(entry.key),
                isTrue,
                reason: '$id positive ${entry.key}',
              );
            } else if (value < 0) {
              expect(
                _primaryDump.contains(entry.key),
                isTrue,
                reason: '$id negative ${entry.key}',
              );
            }
          }

          for (final proc in def.procs) {
            expect(
              proc.statusProfileId != StatusProfileId.none,
              isTrue,
              reason: '$id',
            );
            expect(_isOutgoingProcAllowed(proc), isTrue, reason: '$id $proc');
            final procIdentity = _outgoingProcIdentityKey(
              slot: _slotKeyForWeaponCategory(def.category),
              proc: proc,
            );
            expect(
              usedProcIdentities.add(procIdentity),
              isTrue,
              reason: '$id duplicate proc identity $procIdentity',
            );
          }
          expect(def.reactiveProcs, isEmpty, reason: '$id');

          _expectStatTemplate(
            id: id,
            hasProc: outgoingCount == 1,
            positiveCount: positiveCount,
            negativeCount: negativeCount,
          );
          expect(
            primaryIdentity.add(
              _identitySignature(stats, def.procs, def.reactiveProcs),
            ),
            isTrue,
            reason: '$id duplicate primary identity',
          );
        } else {
          for (final entry in stats.entries) {
            final value = entry.value;
            if (value > 0) {
              expect(
                _offhandPositive.contains(entry.key),
                isTrue,
                reason: '$id positive ${entry.key}',
              );
            } else if (value < 0) {
              expect(
                _offhandDump.contains(entry.key),
                isTrue,
                reason: '$id negative ${entry.key}',
              );
            }
          }

          expect(def.procs, isEmpty, reason: '$id');
          for (final proc in def.reactiveProcs) {
            expect(
              proc.statusProfileId != StatusProfileId.none,
              isTrue,
              reason: '$id',
            );
            expect(
              _isOffhandReactiveProcAllowed(proc),
              isTrue,
              reason: '$id $proc',
            );
            final procIdentity = _reactiveProcIdentityKey(
              slot: _slotKeyForWeaponCategory(def.category),
              proc: proc,
            );
            expect(
              usedProcIdentities.add(procIdentity),
              isTrue,
              reason: '$id duplicate proc identity $procIdentity',
            );
          }

          _expectStatTemplate(
            id: id,
            hasProc: reactiveCount == 1,
            positiveCount: positiveCount,
            negativeCount: negativeCount,
          );
          expect(
            offhandIdentity.add(
              _identitySignature(stats, def.procs, def.reactiveProcs),
            ),
            isTrue,
            reason: '$id duplicate offhand identity',
          );
        }
      }
    });

    test('spellbook catalog respects slot identity (stats-only, no procs)', () {
      const catalog = SpellBookCatalog();
      final identity = <String>{};

      for (final id in SpellBookId.values) {
        final def = catalog.get(id);
        expect(def.procs, isEmpty, reason: '$id');
        final stats = _statMap(def.stats);

        for (final entry in stats.entries) {
          final value = entry.value;
          if (value == 0) continue;
          expect(value.abs() >= 500, isTrue, reason: '$id ${entry.key}');
          expect(value % 500 == 0, isTrue, reason: '$id ${entry.key}: $value');
          expect(
            _isWithinStatBounds(entry.key, value),
            isTrue,
            reason: '$id ${entry.key}: $value',
          );
          if (value > 0) {
            expect(
              _spellbookPositive.contains(entry.key),
              isTrue,
              reason: '$id positive ${entry.key}',
            );
          } else if (value < 0) {
            expect(
              _spellbookDump.contains(entry.key),
              isTrue,
              reason: '$id negative ${entry.key}',
            );
          }
        }

        _expectStatTemplate(
          id: id,
          hasProc: false,
          positiveCount: _positiveStatCount(stats),
          negativeCount: _negativeStatCount(stats),
        );
        expect(
          identity.add(_identitySignature(stats, const [], const [])),
          isTrue,
          reason: '$id duplicate identity',
        );
      }
    });

    test(
      'accessory catalog respects dump rules and low-health sustain proc rules',
      () {
        const catalog = AccessoryCatalog();
        final identity = <String>{};
        final usedProcIdentities = <String>{};

        for (final id in AccessoryId.values) {
          final def = catalog.get(id);
          final stats = _statMap(def.stats);
          _expectProcClusterConstraints(
            id: id,
            procs: const <WeaponProc>[],
            reactiveProcs: def.reactiveProcs,
          );

          for (final entry in stats.entries) {
            final value = entry.value;
            if (value == 0) continue;
            expect(value.abs() >= 500, isTrue, reason: '$id ${entry.key}');
            expect(
              value % 500 == 0,
              isTrue,
              reason: '$id ${entry.key}: $value',
            );
            expect(
              _isWithinStatBounds(entry.key, value),
              isTrue,
              reason: '$id ${entry.key}: $value',
            );
            if (value < 0) {
              expect(
                _accessoryDump.contains(entry.key),
                isTrue,
                reason: '$id negative ${entry.key}',
              );
            }
          }

          for (final proc in def.reactiveProcs) {
            expect(proc.hook, ReactiveProcHook.onLowHealth, reason: '$id');
            expect(proc.target, ReactiveProcTarget.self, reason: '$id');
            expect(proc.chanceBp, 10000, reason: '$id');
            expect(
              proc.lowHealthThresholdBp >= 2500 &&
                  proc.lowHealthThresholdBp <= 3500,
              isTrue,
              reason: '$id threshold',
            );
            expect(
              proc.internalCooldownTicks >= 1800,
              isTrue,
              reason: '$id cooldown',
            );
            expect(
              _statusFamily(proc.statusProfileId),
              _StatusFamily.sustain,
              reason: '$id',
            );
            final procIdentity = _reactiveProcIdentityKey(
              slot: 'accessory',
              proc: proc,
            );
            expect(
              usedProcIdentities.add(procIdentity),
              isTrue,
              reason: '$id duplicate proc identity $procIdentity',
            );
          }

          _expectStatTemplate(
            id: id,
            hasProc: def.reactiveProcs.isNotEmpty,
            positiveCount: _positiveStatCount(stats),
            negativeCount: _negativeStatCount(stats),
          );
          expect(
            identity.add(
              _identitySignature(
                stats,
                const <WeaponProc>[],
                def.reactiveProcs,
              ),
            ),
            isTrue,
            reason: '$id duplicate identity',
          );
        }
      },
    );
  });
}

int _positiveStatCount(Map<String, int> stats) =>
    stats.values.where((value) => value > 0).length;

int _negativeStatCount(Map<String, int> stats) =>
    stats.values.where((value) => value < 0).length;

void _expectStatTemplate({
  required Object id,
  required bool hasProc,
  required int positiveCount,
  required int negativeCount,
}) {
  if (hasProc) {
    expect(positiveCount, 2, reason: '$id positive-count');
    expect(negativeCount, 1, reason: '$id dump-count');
    return;
  }
  expect(positiveCount, 3, reason: '$id positive-count');
  expect(negativeCount, 1, reason: '$id dump-count');
}

String _identitySignature(
  Map<String, int> stats,
  List<WeaponProc> procs,
  List<ReactiveProc> reactiveProcs,
) {
  final statPart =
      stats.entries
          .where((entry) => entry.value != 0)
          .map((entry) => '${entry.key}:${entry.value}')
          .toList()
        ..sort();

  final outgoingPart =
      procs
          .map(
            (proc) =>
                '${proc.hook.name}:${proc.statusProfileId.name}:${proc.chanceBp}',
          )
          .toList()
        ..sort();
  final reactivePart =
      reactiveProcs
          .map(
            (proc) =>
                '${proc.hook.name}:${proc.statusProfileId.name}:${proc.target.name}:${proc.chanceBp}:${proc.lowHealthThresholdBp}:${proc.internalCooldownTicks}',
          )
          .toList()
        ..sort();

  final out = outgoingPart.isEmpty ? 'none' : outgoingPart.join(',');
  final react = reactivePart.isEmpty ? 'none' : reactivePart.join(',');
  return '${statPart.join('|')}|out:$out|react:$react';
}

Map<String, int> _statMap(GearStatBonuses stats) => <String, int>{
  'healthBonusBp': stats.healthBonusBp,
  'manaBonusBp': stats.manaBonusBp,
  'staminaBonusBp': stats.staminaBonusBp,
  'healthRegenBonusBp': stats.healthRegenBonusBp,
  'manaRegenBonusBp': stats.manaRegenBonusBp,
  'staminaRegenBonusBp': stats.staminaRegenBonusBp,
  'defenseBonusBp': stats.defenseBonusBp,
  'globalPowerBonusBp': stats.globalPowerBonusBp,
  'globalCritChanceBonusBp': stats.globalCritChanceBonusBp,
  'moveSpeedBonusBp': stats.moveSpeedBonusBp,
  'cooldownReductionBp': stats.cooldownReductionBp,
  'physicalResistanceBp': stats.physicalResistanceBp,
  'fireResistanceBp': stats.fireResistanceBp,
  'iceResistanceBp': stats.iceResistanceBp,
  'waterResistanceBp': stats.waterResistanceBp,
  'thunderResistanceBp': stats.thunderResistanceBp,
  'acidResistanceBp': stats.acidResistanceBp,
  'darkResistanceBp': stats.darkResistanceBp,
  'bleedResistanceBp': stats.bleedResistanceBp,
  'earthResistanceBp': stats.earthResistanceBp,
  'holyResistanceBp': stats.holyResistanceBp,
};

const Set<String> _typedResistance = <String>{
  'physicalResistanceBp',
  'fireResistanceBp',
  'iceResistanceBp',
  'waterResistanceBp',
  'thunderResistanceBp',
  'acidResistanceBp',
  'darkResistanceBp',
  'bleedResistanceBp',
  'earthResistanceBp',
  'holyResistanceBp',
};

const Set<String> _primaryPositive = <String>{
  'globalPowerBonusBp',
  'globalCritChanceBonusBp',
  'staminaBonusBp',
  'staminaRegenBonusBp',
};

const Set<String> _primaryDump = <String>{
  'healthBonusBp',
  'defenseBonusBp',
  'manaRegenBonusBp',
};

const Set<String> _offhandPositive = <String>{
  'defenseBonusBp',
  'staminaBonusBp',
  'staminaRegenBonusBp',
  ..._typedResistance,
};

const Set<String> _offhandDump = <String>{
  'moveSpeedBonusBp',
  'globalPowerBonusBp',
  'globalCritChanceBonusBp',
};

const Set<String> _spellbookPositive = <String>{
  'manaBonusBp',
  'manaRegenBonusBp',
  'cooldownReductionBp',
  'globalCritChanceBonusBp',
};

const Set<String> _spellbookDump = <String>{
  'staminaBonusBp',
  'staminaRegenBonusBp',
  'healthRegenBonusBp',
};

const Set<String> _accessoryDump = <String>{
  'manaBonusBp',
  'cooldownReductionBp',
  ..._typedResistance,
};

bool _isWithinStatBounds(String statKey, int valueBp) {
  if (valueBp >= 0) {
    final cap = switch (statKey) {
      'healthBonusBp' || 'manaBonusBp' || 'staminaBonusBp' => 2000,
      'healthRegenBonusBp' ||
      'manaRegenBonusBp' ||
      'staminaRegenBonusBp' => 1200,
      'defenseBonusBp' || 'globalPowerBonusBp' => 1800,
      'globalCritChanceBonusBp' => 1200,
      'moveSpeedBonusBp' => 1000,
      'cooldownReductionBp' => 800,
      _ when _typedResistance.contains(statKey) => 2500,
      _ => 0,
    };
    return valueBp <= cap;
  }

  final floor = switch (statKey) {
    'healthBonusBp' || 'manaBonusBp' || 'staminaBonusBp' => -1000,
    'healthRegenBonusBp' || 'manaRegenBonusBp' || 'staminaRegenBonusBp' => -800,
    'defenseBonusBp' ||
    'globalPowerBonusBp' ||
    'globalCritChanceBonusBp' ||
    'moveSpeedBonusBp' ||
    'cooldownReductionBp' => -1000,
    _ when _typedResistance.contains(statKey) => -1000,
    _ => 0,
  };
  return valueBp >= floor;
}

bool _isOutgoingProcAllowed(WeaponProc proc) {
  final family = _statusFamily(proc.statusProfileId);
  if (family == _StatusFamily.neutral) return false;
  switch (proc.hook) {
    case ProcHook.onHit:
      return proc.chanceBp <= 3500 &&
          (family == _StatusFamily.dot || family == _StatusFamily.softControl);
    case ProcHook.onCrit:
      return proc.chanceBp <= 10000 &&
          (family == _StatusFamily.debuff || family == _StatusFamily.hardCc);
    case ProcHook.onKill:
      return proc.chanceBp == 10000 && family == _StatusFamily.selfBuff;
    case ProcHook.onBlock:
      return false;
  }
}

bool _isOffhandReactiveProcAllowed(ReactiveProc proc) {
  final family = _statusFamily(proc.statusProfileId);
  if (family == _StatusFamily.neutral || family == _StatusFamily.sustain) {
    return false;
  }
  switch (proc.hook) {
    case ReactiveProcHook.onDamaged:
      return proc.chanceBp <= 3500 &&
          proc.target == ReactiveProcTarget.attacker &&
          (family == _StatusFamily.dot || family == _StatusFamily.softControl);
    case ReactiveProcHook.onLowHealth:
      return proc.chanceBp == 10000 &&
          proc.target == ReactiveProcTarget.self &&
          proc.lowHealthThresholdBp >= 2500 &&
          proc.lowHealthThresholdBp <= 3500 &&
          proc.internalCooldownTicks >= 1800 &&
          family == _StatusFamily.selfBuff;
  }
}

void _expectProcClusterConstraints({
  required Object id,
  required List<WeaponProc> procs,
  required List<ReactiveProc> reactiveProcs,
}) {
  final totalEntries = procs.length + reactiveProcs.length;
  expect(totalEntries <= 2, isTrue, reason: '$id proc-cluster-budget');
  if (totalEntries <= 1) return;

  final hookKeys = <String>{
    for (final proc in procs) 'out:${proc.hook.name}',
    for (final proc in reactiveProcs) 'react:${proc.hook.name}',
  };
  expect(
    hookKeys.length,
    totalEntries,
    reason: '$id proc-cluster duplicate hook',
  );

  final themes = <_ProcClusterTheme>{
    for (final proc in procs)
      _clusterThemeForStatusFamily(_statusFamily(proc.statusProfileId)),
    for (final proc in reactiveProcs)
      _clusterThemeForStatusFamily(_statusFamily(proc.statusProfileId)),
  };
  expect(themes.length, 1, reason: '$id proc-cluster theme mismatch');
}

String _slotKeyForWeaponCategory(WeaponCategory category) {
  switch (category) {
    case WeaponCategory.primary:
      return 'mainWeapon';
    case WeaponCategory.offHand:
      return 'offhandWeapon';
    case WeaponCategory.projectile:
      return 'projectileWeapon';
  }
}

_ProcClusterTheme _clusterThemeForStatusFamily(_StatusFamily family) {
  switch (family) {
    case _StatusFamily.selfBuff:
    case _StatusFamily.sustain:
      return _ProcClusterTheme.defensive;
    case _StatusFamily.dot:
    case _StatusFamily.softControl:
    case _StatusFamily.hardCc:
    case _StatusFamily.debuff:
      return _ProcClusterTheme.offensive;
    case _StatusFamily.neutral:
      return _ProcClusterTheme.neutral;
  }
}

String _outgoingTargetPolicy(ProcHook hook) {
  switch (hook) {
    case ProcHook.onHit:
    case ProcHook.onCrit:
    case ProcHook.onBlock:
      return 'target';
    case ProcHook.onKill:
      return 'self';
  }
}

String _outgoingProcIdentityKey({
  required String slot,
  required WeaponProc proc,
}) {
  return '$slot:${proc.hook.name}:${_statusFamily(proc.statusProfileId).name}:${_outgoingTargetPolicy(proc.hook)}';
}

String _reactiveProcIdentityKey({
  required String slot,
  required ReactiveProc proc,
}) {
  return '$slot:${proc.hook.name}:${_statusFamily(proc.statusProfileId).name}:${proc.target.name}';
}

enum _StatusFamily {
  neutral,
  dot,
  softControl,
  hardCc,
  debuff,
  selfBuff,
  sustain,
}

enum _ProcClusterTheme { neutral, offensive, defensive }

_StatusFamily _statusFamily(StatusProfileId id) {
  return switch (id) {
    StatusProfileId.none => _StatusFamily.neutral,
    StatusProfileId.meleeBleed ||
    StatusProfileId.burnOnHit => _StatusFamily.dot,
    StatusProfileId.slowOnHit ||
    StatusProfileId.drenchOnHit => _StatusFamily.softControl,
    StatusProfileId.stunOnHit ||
    StatusProfileId.silenceOnHit => _StatusFamily.hardCc,
    StatusProfileId.acidOnHit ||
    StatusProfileId.weakenOnHit => _StatusFamily.debuff,
    StatusProfileId.speedBoost ||
    StatusProfileId.focus ||
    StatusProfileId.arcaneWard => _StatusFamily.selfBuff,
    StatusProfileId.restoreHealth ||
    StatusProfileId.restoreMana ||
    StatusProfileId.restoreStamina => _StatusFamily.sustain,
  };
}
