import '../../../../core/accessories/accessory_catalog.dart';
import '../../../../core/accessories/accessory_def.dart';
import '../../../../core/accessories/accessory_id.dart';
import '../../../../core/meta/gear_slot.dart';
import '../../../../core/projectiles/projectile_item_catalog.dart';
import '../../../../core/projectiles/projectile_item_def.dart';
import '../../../../core/projectiles/projectile_item_id.dart';
import '../../../../core/spells/spell_book_catalog.dart';
import '../../../../core/spells/spell_book_def.dart';
import '../../../../core/spells/spell_book_id.dart';
import '../../../../core/stats/character_stat_id.dart';
import '../../../../core/stats/gear_stat_bonuses.dart';
import '../../../../core/weapons/weapon_def.dart';
import '../../../../core/weapons/weapon_id.dart';
import '../../../../core/weapons/weapon_catalog.dart';

/// UI tone hints for stat values.
enum GearStatLineTone { neutral, positive, negative }

/// Display-ready stat row used by the stats panel.
class GearStatLine {
  const GearStatLine(
    this.label,
    this.value, {
    this.tone = GearStatLineTone.neutral,
  });

  final String label;
  final String value;
  final GearStatLineTone tone;
}

/// Builds base stat lines for a selected gear item.
///
/// This is pure computation (no widget or state dependencies).
List<GearStatLine> gearStatsFor(GearSlot slot, Object id) {
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final def = const WeaponCatalog().get(id as WeaponId);
      return _weaponDefStats(def);
    case GearSlot.throwingWeapon:
      final def = const ProjectileItemCatalog().get(id as ProjectileItemId);
      return _projectileItemStats(def);
    case GearSlot.spellBook:
      final def = const SpellBookCatalog().get(id as SpellBookId);
      return _spellBookStats(def);
    case GearSlot.accessory:
      final def = const AccessoryCatalog().get(id as AccessoryId);
      return _accessoryStats(def);
  }
}

/// Builds compare stat lines between currently equipped and selected gear.
///
/// Returns an empty list when both ids are the same item.
List<GearStatLine> gearCompareStats(
  GearSlot slot, {
  required Object equipped,
  required Object candidate,
}) {
  if (equipped == candidate) return const <GearStatLine>[];
  switch (slot) {
    case GearSlot.mainWeapon:
    case GearSlot.offhandWeapon:
      final a = const WeaponCatalog().get(equipped as WeaponId);
      final b = const WeaponCatalog().get(candidate as WeaponId);
      return _diffWeaponStats(a, b);
    case GearSlot.throwingWeapon:
      final a = const ProjectileItemCatalog().get(equipped as ProjectileItemId);
      final b = const ProjectileItemCatalog().get(
        candidate as ProjectileItemId,
      );
      return _diffWeaponStatsLike(a.stats, b.stats);
    case GearSlot.spellBook:
      final a = const SpellBookCatalog().get(equipped as SpellBookId);
      final b = const SpellBookCatalog().get(candidate as SpellBookId);
      return _diffWeaponStatsLike(a.stats, b.stats);
    case GearSlot.accessory:
      final a = const AccessoryCatalog().get(equipped as AccessoryId);
      final b = const AccessoryCatalog().get(candidate as AccessoryId);
      return _diffAccessoryStats(a.stats, b.stats);
  }
}

/// Empty state text for the compare section.
String gearCompareEmptyText({
  required Object? selectedId,
  required Object? equippedForCompare,
}) {
  if (selectedId != null &&
      equippedForCompare != null &&
      selectedId == equippedForCompare) {
    return 'This gear is currently equipped.';
  }
  return 'No stat differences.';
}

List<GearStatLine> _weaponDefStats(WeaponDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine('Type', _enumLabel(def.weaponType.name)),
  ];
  _addCoreStatLines(lines, stats);
  return lines;
}

List<GearStatLine> _projectileItemStats(ProjectileItemDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine('Type', _enumLabel(def.weaponType.name)),
    GearStatLine('Damage Type', _enumLabel(def.damageType.name)),
    GearStatLine('Ballistic', def.ballistic ? 'Yes' : 'No'),
  ];
  _addCoreStatLines(lines, stats);
  return lines;
}

List<GearStatLine> _spellBookStats(SpellBookDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine('Type', _enumLabel(def.weaponType.name)),
    GearStatLine(
      'Damage Type',
      def.damageType == null ? 'Ability' : _enumLabel(def.damageType!.name),
    ),
  ];
  _addCoreStatLines(lines, stats);
  return lines;
}

List<GearStatLine> _accessoryStats(AccessoryDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[];
  _addCoreStatLines(lines, stats);
  return lines;
}

void _addBpStat(List<GearStatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(GearStatLine(label, _bpPct(value)));
}

List<GearStatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
  return _diffStatBonuses(equipped.stats, candidate.stats);
}

List<GearStatLine> _diffWeaponStatsLike(GearStatBonuses a, GearStatBonuses b) {
  return _diffStatBonuses(a, b);
}

List<GearStatLine> _diffAccessoryStats(GearStatBonuses a, GearStatBonuses b) {
  return _diffStatBonuses(a, b);
}

void _addCoreStatLines(List<GearStatLine> lines, GearStatBonuses stats) {
  _addBpStat(lines, _labelFor(CharacterStatId.health), stats.healthBonusBp);
  _addBpStat(lines, _labelFor(CharacterStatId.mana), stats.manaBonusBp);
  _addBpStat(lines, _labelFor(CharacterStatId.stamina), stats.staminaBonusBp);
  _addBpStat(lines, _labelFor(CharacterStatId.defense), stats.defenseBonusBp);
  _addBpStat(lines, _labelFor(CharacterStatId.power), _effectivePowerBp(stats));
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.moveSpeed),
    stats.moveSpeedBonusBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.cooldownReduction),
    stats.cooldownReductionBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.critChance),
    _effectiveCritChanceBp(stats),
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.physicalResistance),
    stats.physicalResistanceBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.fireResistance),
    stats.fireResistanceBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.iceResistance),
    stats.iceResistanceBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.thunderResistance),
    stats.thunderResistanceBp,
  );
  _addBpStat(
    lines,
    _labelFor(CharacterStatId.bleedResistance),
    stats.bleedResistanceBp,
  );
}

List<GearStatLine> _diffStatBonuses(GearStatBonuses a, GearStatBonuses b) {
  final lines = <GearStatLine>[];
  if (b.healthBonusBp != a.healthBonusBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.health),
        a.healthBonusBp,
        b.healthBonusBp,
      ),
    );
  }
  if (b.manaBonusBp != a.manaBonusBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.mana),
        a.manaBonusBp,
        b.manaBonusBp,
      ),
    );
  }
  if (b.staminaBonusBp != a.staminaBonusBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.stamina),
        a.staminaBonusBp,
        b.staminaBonusBp,
      ),
    );
  }
  if (b.defenseBonusBp != a.defenseBonusBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.defense),
        a.defenseBonusBp,
        b.defenseBonusBp,
      ),
    );
  }
  if (b.moveSpeedBonusBp != a.moveSpeedBonusBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.moveSpeed),
        a.moveSpeedBonusBp,
        b.moveSpeedBonusBp,
      ),
    );
  }
  final aPowerBp = _effectivePowerBp(a);
  final bPowerBp = _effectivePowerBp(b);
  if (bPowerBp != aPowerBp) {
    lines.add(
      _deltaBpLine(_labelFor(CharacterStatId.power), aPowerBp, bPowerBp),
    );
  }
  if (b.cooldownReductionBp != a.cooldownReductionBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.cooldownReduction),
        a.cooldownReductionBp,
        b.cooldownReductionBp,
      ),
    );
  }
  final aCritChanceBp = _effectiveCritChanceBp(a);
  final bCritChanceBp = _effectiveCritChanceBp(b);
  if (bCritChanceBp != aCritChanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.critChance),
        aCritChanceBp,
        bCritChanceBp,
      ),
    );
  }
  if (b.physicalResistanceBp != a.physicalResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.physicalResistance),
        a.physicalResistanceBp,
        b.physicalResistanceBp,
      ),
    );
  }
  if (b.fireResistanceBp != a.fireResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.fireResistance),
        a.fireResistanceBp,
        b.fireResistanceBp,
      ),
    );
  }
  if (b.iceResistanceBp != a.iceResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.iceResistance),
        a.iceResistanceBp,
        b.iceResistanceBp,
      ),
    );
  }
  if (b.thunderResistanceBp != a.thunderResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.thunderResistance),
        a.thunderResistanceBp,
        b.thunderResistanceBp,
      ),
    );
  }
  if (b.bleedResistanceBp != a.bleedResistanceBp) {
    lines.add(
      _deltaBpLine(
        _labelFor(CharacterStatId.bleedResistance),
        a.bleedResistanceBp,
        b.bleedResistanceBp,
      ),
    );
  }
  return lines;
}

GearStatLine _deltaBpLine(String label, int equippedValue, int candidateValue) {
  final delta = candidateValue - equippedValue;
  return GearStatLine(
    label,
    _signedPercent(delta / 100),
    tone: _toneForDelta(delta),
  );
}

GearStatLineTone _toneForDelta(int delta) {
  if (delta > 0) return GearStatLineTone.positive;
  if (delta < 0) return GearStatLineTone.negative;
  return GearStatLineTone.neutral;
}

int _effectivePowerBp(GearStatBonuses stats) {
  return stats.powerBonusBp + stats.globalPowerBonusBp;
}

int _effectiveCritChanceBp(GearStatBonuses stats) {
  return stats.critChanceBonusBp + stats.globalCritChanceBonusBp;
}

String _bpPct(int bp) => _signedPercent(bp / 100);

String _signedPercent(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${_formatNumber(value)}%';
}

String _formatNumber(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _enumLabel(String source) {
  final normalized = source
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  final words = normalized.split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) {
        if (word == word.toUpperCase()) return word;
        return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String _labelFor(CharacterStatId id) => characterStatDescriptor(id).displayName;
