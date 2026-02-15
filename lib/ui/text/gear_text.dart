import '../../core/accessories/accessory_id.dart';
import '../../core/meta/gear_slot.dart';
import '../../core/projectiles/projectile_id.dart';
import '../../core/spellBook/spell_book_id.dart';
import '../../core/weapons/weapon_id.dart';

/// User-facing display name for a [WeaponId].
String weaponDisplayName(WeaponId id) {
  return _weaponDisplayNameOverrides[id] ?? _titleCaseEnum(id.name);
}

/// User-facing short description for a [WeaponId].
String weaponDescription(WeaponId id) {
  return _weaponDescriptionOverrides[id] ?? _defaultDescription;
}

/// User-facing display name for a [ProjectileId].
///
/// Shared by gear picker and projectile source picker.
String projectileDisplayName(ProjectileId id) {
  return _projectileDisplayNameOverrides[id] ?? _titleCaseEnum(id.name);
}

/// User-facing short description for a [ProjectileId].
String projectileDescription(ProjectileId id) {
  return _projectileDescriptionOverrides[id] ?? _defaultDescription;
}

/// User-facing display name for a [SpellBookId].
String spellBookDisplayName(SpellBookId id) {
  return _spellBookDisplayNameOverrides[id] ?? _titleCaseEnum(id.name);
}

/// User-facing short description for a [SpellBookId].
String spellBookDescription(SpellBookId id) {
  return _spellBookDescriptionOverrides[id] ?? _defaultDescription;
}

/// User-facing display name for an [AccessoryId].
String accessoryDisplayName(AccessoryId id) {
  return _accessoryDisplayNameOverrides[id] ?? _titleCaseEnum(id.name);
}

/// User-facing short description for an [AccessoryId].
String accessoryDescription(AccessoryId id) {
  return _accessoryDescriptionOverrides[id] ?? _defaultDescription;
}

/// Returns the display text for a gear item shown in UI.
///
/// This is intentionally centralized so call sites can later move to
/// localization keys without rewriting widget logic.
String gearDisplayNameForSlot(GearSlot slot, Object id) {
  return switch (slot) {
    GearSlot.mainWeapon ||
    GearSlot.offhandWeapon => weaponDisplayName(id as WeaponId),
    GearSlot.throwingWeapon => projectileDisplayName(id as ProjectileId),
    GearSlot.spellBook => spellBookDisplayName(id as SpellBookId),
    GearSlot.accessory => accessoryDisplayName(id as AccessoryId),
  };
}

/// Returns a short description for a gear item shown in UI.
String gearDescriptionForSlot(GearSlot slot, Object id) {
  return switch (slot) {
    GearSlot.mainWeapon ||
    GearSlot.offhandWeapon => weaponDescription(id as WeaponId),
    GearSlot.throwingWeapon => projectileDescription(id as ProjectileId),
    GearSlot.spellBook => spellBookDescription(id as SpellBookId),
    GearSlot.accessory => accessoryDescription(id as AccessoryId),
  };
}

String _titleCaseEnum(String source) {
  final normalized = source
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  final words = normalized.split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

const String _defaultDescription = 'No description available yet.';

const Map<WeaponId, String> _weaponDisplayNameOverrides = <WeaponId, String>{
  WeaponId.woodenSword: 'Wooden Sword',
  WeaponId.basicSword: 'Basic Sword',
  WeaponId.solidSword: 'Solid Sword',
  WeaponId.woodenShield: 'Wooden Shield',
  WeaponId.basicShield: 'Basic Shield',
  WeaponId.solidShield: 'Solid Shield',
};

const Map<WeaponId, String> _weaponDescriptionOverrides = <WeaponId, String>{
  WeaponId.woodenSword: 'Starter blade with low power.',
  WeaponId.basicSword: 'Balanced one-handed sword.',
  WeaponId.solidSword: 'Heavier one-handed sword with higher power.',
  WeaponId.woodenShield: 'Starter shield with low output.',
  WeaponId.basicShield: 'Balanced shield for defensive actions.',
  WeaponId.solidShield: 'Reinforced shield with higher output.',
};

const Map<ProjectileId, String> _projectileDisplayNameOverrides =
    <ProjectileId, String>{
      ProjectileId.iceBolt: 'Ice Bolt',
      ProjectileId.fireBolt: 'Fire Bolt',
      ProjectileId.acidBolt: 'Acid Bolt',
      ProjectileId.darkBolt: 'Dark Bolt',
      ProjectileId.earthBolt: 'Earth Bolt',
      ProjectileId.holyBolt: 'Holy Bolt',
      ProjectileId.thunderBolt: 'Thunder Bolt',
      ProjectileId.throwingKnife: 'Throwing Knife',
      ProjectileId.throwingAxe: 'Throwing Axe',
    };

const Map<ProjectileId, String> _projectileDescriptionOverrides =
    <ProjectileId, String>{
      ProjectileId.iceBolt: 'Spell projectile that chills on hit.',
      ProjectileId.fireBolt: 'Spell projectile that burns on hit.',
      ProjectileId.acidBolt:
          'Spell projectile that corrodes and increases damage taken.',
      ProjectileId.darkBolt:
          'Spell projectile that weakens enemy outgoing damage on hit.',
      ProjectileId.earthBolt: 'Spell projectile that stuns enemies on hit.',
      ProjectileId.holyBolt:
          'Spell projectile that silences enemy casts for 3 seconds.',
      ProjectileId.thunderBolt: 'Spell projectile with thunder damage.',
      ProjectileId.throwingKnife: 'Fast ballistic throw with a light arc.',
      ProjectileId.throwingAxe: 'Heavy ballistic throw with a steeper arc.',
    };

const Map<SpellBookId, String> _spellBookDisplayNameOverrides =
    <SpellBookId, String>{
      SpellBookId.basicSpellBook: 'Basic Spellbook',
      SpellBookId.solidSpellBook: 'Solid Spellbook',
      SpellBookId.epicSpellBook: 'Epic Spellbook',
    };

const Map<SpellBookId, String> _spellBookDescriptionOverrides =
    <SpellBookId, String>{
      SpellBookId.basicSpellBook: 'Starter spell focus with lower output.',
      SpellBookId.solidSpellBook: 'Balanced spell focus.',
      SpellBookId.epicSpellBook: 'Advanced spell focus with higher output.',
    };

const Map<AccessoryId, String> _accessoryDisplayNameOverrides =
    <AccessoryId, String>{
      AccessoryId.speedBoots: 'Speed Boots',
      AccessoryId.goldenRing: 'Golden Ring',
      AccessoryId.teethNecklace: 'Teeth Necklace',
    };

const Map<AccessoryId, String> _accessoryDescriptionOverrides =
    <AccessoryId, String>{
      AccessoryId.speedBoots: 'Improves move speed.',
      AccessoryId.goldenRing: 'Improves maximum health.',
      AccessoryId.teethNecklace: 'Improves maximum stamina.',
    };
