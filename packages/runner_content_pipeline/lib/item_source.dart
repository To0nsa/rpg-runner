/// Strict item authoring and deterministic Dart compilation. No repository I/O.
library;

import 'dart:convert';

import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/players/character_equipment_policy.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/weapons/weapon_proc.dart';
import 'package:runner_core/weapons/reactive_proc.dart';

part 'src/items/item_fields.dart';

/// Category fixes the generated enum and typed constructor, never backend prices.
enum ItemCategory {
  weapon('weapons', 'weapon', 'WeaponId', 'WeaponDef'),
  accessory('accessories', 'accessory', 'AccessoryId', 'AccessoryDef'),
  spellBook('spellBook', 'spell_book', 'SpellBookId', 'SpellBookDef'),
  projectile('projectiles', 'projectile', 'ProjectileId', 'ProjectileItemDef');

  const ItemCategory(
    this.folder,
    this.fileStem,
    this.enumType,
    this.constructor,
  );
  final String folder, fileStem, enumType, constructor;
}

/// Names and art references accompany data but never enter Core runtime outputs.
/// JSON is deep-frozen so session Undo cannot be changed by a caller's form map.
final class ItemSource {
  ItemSource._(
    this.category,
    this.id,
    this.ordinal,
    this.names,
    this.icon,
    this.data,
    this.renderAs,
  );
  final ItemCategory category;
  final String id, icon;
  final int ordinal;
  final Map<String, String> names;
  final Map<String, Object?> data;
  final String? renderAs;
  String get key => '${category.name}/$id';
  WeaponType? get family => category == ItemCategory.accessory
      ? null
      : WeaponType.values.byName((data['weaponType'] ?? 'spell') as String);
  GearSlot? get slot => switch (category) {
    ItemCategory.weapon =>
      data['category'] == 'primary'
          ? GearSlot.mainWeapon
          : GearSlot.offhandWeapon,
    ItemCategory.spellBook => GearSlot.spellBook,
    ItemCategory.accessory => GearSlot.accessory,
    ItemCategory.projectile => null,
  };
  List<PlayerCharacterId> get eligibleCharacters => [
    for (final character in PlayerCharacterId.values)
      if (slot == null
          ? CharacterEquipmentPolicy.allowsProjectileFamily(character, family!)
          : CharacterEquipmentPolicy.allowsFamily(character, slot!, family))
        character,
  ];

  factory ItemSource.decode(Object? raw) {
    final m = _object(raw, 'item');
    _keys(m, {
      'category',
      'id',
      'ordinal',
      'name',
      'icon',
      'data',
      'renderAs',
    }, 'item');
    final category = ItemCategory.values
        .where((e) => e.name == m['category'])
        .firstOrNull;
    if (category == null) {
      _fail('item.category', 'Choose an existing item category.');
    }
    final id = m['id'];
    if (id is! String ||
        !RegExp(r'^[a-z][A-Za-z0-9_]{0,79}$').hasMatch(id) ||
        reservedItemIds.contains(id)) {
      _fail(
        'item.id',
        'Use a unique lower-case-leading Dart identifier (up to 80 characters); reserved IDs cannot be reused.',
      );
    }
    final ordinal = m['ordinal'];
    if (ordinal is! int || ordinal < 0) {
      _fail(id, 'ordinal must be a nonnegative integer.');
    }
    final names = _object(m['name'], '$id.name');
    _keys(names, {'en', 'fr'}, '$id.name');
    for (final language in ['en', 'fr']) {
      final name = names[language];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 120 ||
          name.contains(RegExp(r'[\r\n]'))) {
        _fail('$id.name.$language', 'Enter a name of 1–120 characters.');
      }
    }
    if (m['icon'] is! String) {
      _fail('$id.icon', 'Select an existing canonical icon.');
    }
    final data = _object(m['data'], '$id.data');
    validateItemFields(data, itemFields(category), '$id.data');
    if (category == ItemCategory.projectile && m['renderAs'] is! String) {
      _fail('$id.renderAs', 'Select an existing projectile render profile.');
    }
    if (category != ItemCategory.projectile && m.containsKey('renderAs')) {
      _fail('$id.renderAs', 'Only projectile items have a render profile.');
    }
    final item = ItemSource._(
      category,
      id,
      ordinal,
      Map.unmodifiable(names.cast<String, String>()),
      m['icon'] as String,
      _freeze(data) as Map<String, Object?>,
      m['renderAs'] as String?,
    );
    if (category == ItemCategory.weapon &&
        data['category'] == 'primary' &&
        ((data['reactiveProcs'] as List?)?.isNotEmpty ?? false)) {
      _fail(
        '$id.reactiveProcs',
        'Reactive effects are supported only by offhand equipment and accessories.',
      );
    }
    if (category == ItemCategory.weapon &&
        data['category'] == 'offHand' &&
        data['isTwoHanded'] == true) {
      _fail('$id.isTwoHanded', 'Only primary weapons can occupy both hands.');
    }
    if (item.eligibleCharacters.isEmpty) {
      _fail(
        id,
        'This equipment family is not supported in this slot by a playable character.',
      );
    }
    return item;
  }

  Map<String, Object?> toJson() => {
    'category': category.name,
    'id': id,
    'ordinal': ordinal,
    'name': Map.of(names),
    'icon': icon,
    'data': jsonDecode(jsonEncode(data)),
    if (renderAs != null) 'renderAs': renderAs,
  };
}

/// Retired wire identities and Dart language/Enum members may never be recycled.
const reservedItemIds = {
  'ironBracers',
  'eloiseWip',
  'unknown',
  'values',
  'index',
  'name',
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// One ordered catalog; internal projectile ordinals reserve their existing ABI.
final class ItemCatalogSource {
  ItemCatalogSource._(this.items, this.internalProjectiles);
  final List<ItemSource> items;
  final Map<int, String> internalProjectiles;
  factory ItemCatalogSource.decode(String text) {
    final root = _object(jsonDecode(text), 'items');
    _keys(root, {'schemaVersion', 'items', 'internalProjectiles'}, 'items');
    if (root['schemaVersion'] != 1 ||
        root['items'] is! List ||
        root['internalProjectiles'] is! List) {
      _fail('items', 'Expected item source schema 1.');
    }
    final items = (root['items'] as List).map(ItemSource.decode).toList();
    final internal = <int, String>{};
    for (final raw in root['internalProjectiles'] as List) {
      final m = _object(raw, 'internalProjectiles');
      _keys(m, {'id', 'ordinal'}, 'internalProjectiles');
      if (m['id'] is! String ||
          m['ordinal'] is! int ||
          (m['ordinal'] as int) < 0 ||
          internal.containsKey(m['ordinal'])) {
        _fail('internalProjectiles', 'Invalid or duplicate identity ordinal.');
      }
      internal[m['ordinal'] as int] = m['id'] as String;
    }
    final ids = internal.values.toSet();
    if (ids.length != internal.length) {
      _fail('internalProjectiles', 'Duplicate reserved identity.');
    }
    for (final item in items) {
      if (!ids.add(item.id)) _fail(item.id, 'Duplicate or reserved identity.');
    }
    for (final category in ItemCategory.values) {
      final ordinals = [
        for (final i in items)
          if (i.category == category) i.ordinal,
        if (category == ItemCategory.projectile) ...internal.keys,
      ]..sort();
      for (var n = 0; n < ordinals.length; n++) {
        if (ordinals[n] != n) {
          _fail(
            category.name,
            'Ordinals must be unique, contiguous and append-only.',
          );
        }
      }
    }
    items.sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      return c == 0 ? a.ordinal.compareTo(b.ordinal) : c;
    });
    return ItemCatalogSource._(
      List.unmodifiable(items),
      Map.unmodifiable(internal),
    );
  }
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'items': items.map((i) => i.toJson()).toList(),
    'internalProjectiles': [
      for (final e
          in (internalProjectiles.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))))
        {'id': e.value, 'ordinal': e.key},
    ],
  };

  /// Validates caller-supplied canonical art membership without importing Flutter.
  void validatePresentation(Map<String, List<String>> icons) {
    for (final item in items) {
      if (!(icons[item.category.name]?.contains(item.icon) ?? false)) {
        _fail('${item.key}.icon', 'Select an existing canonical icon.');
      }
      if (item.category == ItemCategory.projectile) {
        final template = items
            .where(
              (i) =>
                  i.category == ItemCategory.projectile &&
                  i.id == item.renderAs,
            )
            .firstOrNull;
        if (!(icons['projectile']?.contains(item.renderAs) ?? false) ||
            template == null ||
            template.family != item.family) {
          _fail(
            '${item.key}.renderAs',
            'Select an existing canonical projectile profile with the same family.',
          );
        }
      }
    }
  }

  /// Prevents authoring from silently migrating saved builds or retained gifts.
  /// Category, ordinal, slot, family and two-handed occupancy are immutable once saved.
  void requireCompatibleWith(ItemCatalogSource previous) {
    if (jsonEncode(toJson()['internalProjectiles']) !=
        jsonEncode(previous.toJson()['internalProjectiles'])) {
      _fail(
        'internalProjectiles',
        'Internal projectile identities are code-owned.',
      );
    }
    final byId = {for (final i in items) i.id: i};
    for (final old in previous.items) {
      final next = byId[old.id];
      if (next == null ||
          next.category != old.category ||
          next.ordinal != old.ordinal) {
        _fail(
          old.id,
          'Existing IDs/categories/ordinals are immutable; deletion and renaming are not supported.',
        );
      }
      if (next.family != old.family ||
          next.slot != old.slot ||
          (next.data['isTwoHanded'] ?? false) !=
              (old.data['isTwoHanded'] ?? false) ||
          !next.eligibleCharacters.toSet().containsAll(
            old.eligibleCharacters,
          )) {
        _fail(
          old.id,
          'Eligibility/slot/family changes can invalidate saved loadouts. Duplicate with a new ID; an existing-ID migration requires a separately reviewed code/release policy. Ownership is never discarded.',
        );
      }
    }
  }
}

Never _fail(String path, String message) =>
    throw FormatException('$path: $message');
Map<String, Object?> _object(Object? raw, String path) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    _fail(path, 'Expected an object.');
  }
  return Map<String, Object?>.from(raw);
}

void _keys(Map<String, Object?> m, Set<String> allowed, String path) {
  for (final key in m.keys) {
    if (!allowed.contains(key)) _fail('$path.$key', 'Unsupported field.');
  }
}

Object? _freeze(Object? value) => value is Map<String, Object?>
    ? Map<String, Object?>.unmodifiable(
        value.map((k, v) => MapEntry(k, _freeze(v))),
      )
    : value is List
    ? List<Object?>.unmodifiable(value.map(_freeze))
    : value;
