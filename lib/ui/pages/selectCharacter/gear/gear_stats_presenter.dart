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
import '../../../../core/weapons/weapon_def.dart';
import '../../../../core/weapons/weapon_id.dart';
import '../../../../core/weapons/weapon_stats.dart';
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
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
  return lines;
}

List<GearStatLine> _projectileItemStats(ProjectileItemDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[
    GearStatLine('Type', _enumLabel(def.weaponType.name)),
    GearStatLine('Damage Type', _enumLabel(def.damageType.name)),
    GearStatLine('Ballistic', def.ballistic ? 'Yes' : 'No'),
  ];
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
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
  _addBpStat(lines, 'Power', stats.powerBonusBp);
  _addBpStat(lines, 'Crit Chance', stats.critChanceBonusBp);
  _addBpStat(lines, 'Crit Damage', stats.critDamageBonusBp);
  return lines;
}

List<GearStatLine> _accessoryStats(AccessoryDef def) {
  final stats = def.stats;
  final lines = <GearStatLine>[];
  _addPct100Stat(lines, 'HP', stats.hpBonus100);
  _addPct100Stat(lines, 'Mana', stats.manaBonus100);
  _addPct100Stat(lines, 'Stamina', stats.staminaBonus100);
  _addBpStat(lines, 'Move Speed', stats.moveSpeedBonusBp);
  _addBpStat(lines, 'CDR', stats.cooldownReductionBp);
  return lines;
}

void _addBpStat(List<GearStatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(GearStatLine(label, _bpPct(value)));
}

void _addPct100Stat(List<GearStatLine> lines, String label, int value) {
  if (value == 0) return;
  lines.add(GearStatLine(label, _pct100(value)));
}

List<GearStatLine> _diffWeaponStats(WeaponDef equipped, WeaponDef candidate) {
  final a = equipped.stats;
  final b = candidate.stats;
  final lines = <GearStatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_deltaBpLine('Power', a.powerBonusBp, b.powerBonusBp));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _deltaBpLine('Crit Chance', a.critChanceBonusBp, b.critChanceBonusBp),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _deltaBpLine('Crit Damage', a.critDamageBonusBp, b.critDamageBonusBp),
    );
  }
  return lines;
}

List<GearStatLine> _diffWeaponStatsLike(WeaponStats a, WeaponStats b) {
  final lines = <GearStatLine>[];
  if (b.powerBonusBp != a.powerBonusBp) {
    lines.add(_deltaBpLine('Power', a.powerBonusBp, b.powerBonusBp));
  }
  if (b.critChanceBonusBp != a.critChanceBonusBp) {
    lines.add(
      _deltaBpLine('Crit Chance', a.critChanceBonusBp, b.critChanceBonusBp),
    );
  }
  if (b.critDamageBonusBp != a.critDamageBonusBp) {
    lines.add(
      _deltaBpLine('Crit Damage', a.critDamageBonusBp, b.critDamageBonusBp),
    );
  }
  return lines;
}

List<GearStatLine> _diffAccessoryStats(AccessoryStats a, AccessoryStats b) {
  final lines = <GearStatLine>[];
  if (b.hpBonus100 != a.hpBonus100) {
    lines.add(_deltaPct100Line('HP', a.hpBonus100, b.hpBonus100));
  }
  if (b.manaBonus100 != a.manaBonus100) {
    lines.add(_deltaPct100Line('Mana', a.manaBonus100, b.manaBonus100));
  }
  if (b.staminaBonus100 != a.staminaBonus100) {
    lines.add(
      _deltaPct100Line('Stamina', a.staminaBonus100, b.staminaBonus100),
    );
  }
  if (b.moveSpeedBonusBp != a.moveSpeedBonusBp) {
    lines.add(
      _deltaBpLine('Move Speed', a.moveSpeedBonusBp, b.moveSpeedBonusBp),
    );
  }
  if (b.cooldownReductionBp != a.cooldownReductionBp) {
    lines.add(
      _deltaBpLine('CDR', a.cooldownReductionBp, b.cooldownReductionBp),
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

GearStatLine _deltaPct100Line(
  String label,
  int equippedValue,
  int candidateValue,
) {
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

String _bpPct(int bp) => _signedPercent(bp / 100);

String _pct100(int fixed100) => _signedPercent(fixed100 / 100);

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
