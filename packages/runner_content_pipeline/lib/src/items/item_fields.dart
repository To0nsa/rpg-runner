part of '../../item_source.dart';

/// Small closed schema shared by strict compilation and category-specific forms.
/// Numeric bounds are authoring safety limits, not alternate simulation rules.
final class ItemField {
  const ItemField.number(
    this.defaultValue, {
    this.min = 0,
    this.max = 1000000,
    this.integer = true,
    this.required = false,
  }) : choices = null,
       enumType = null,
       fields = null,
       constructor = null,
       isList = false;
  const ItemField.boolean(bool value)
    : defaultValue = value,
      min = null,
      max = null,
      integer = false,
      required = false,
      choices = null,
      enumType = null,
      fields = null,
      constructor = null,
      isList = false;
  const ItemField.choice(
    this.enumType,
    this.choices,
    this.defaultValue, {
    this.required = false,
  }) : min = null,
       max = null,
       integer = false,
       fields = null,
       constructor = null,
       isList = false;
  const ItemField.object(this.constructor, this.fields, {this.isList = false})
    : defaultValue = null,
      min = null,
      max = null,
      integer = false,
      required = false,
      choices = null,
      enumType = null;
  final Object? defaultValue;
  final num? min, max;
  final bool integer, required, isList;
  final List<String>? choices;
  final String? enumType, constructor;
  final Map<String, ItemField>? fields;
}

final _damage = ItemField.choice(
  'DamageType',
  DamageType.values.map((v) => v.name).toList(),
  'physical',
);
final _family = ItemField.choice(
  'WeaponType',
  WeaponType.values.map((v) => v.name).toList(),
  'spell',
  required: true,
);
final itemStatFields = <String, ItemField>{
  for (final key in const [
    'healthBonusBp',
    'manaBonusBp',
    'staminaBonusBp',
    'healthRegenBonusBp',
    'manaRegenBonusBp',
    'staminaRegenBonusBp',
    'defenseBonusBp',
    'globalPowerBonusBp',
    'globalCritChanceBonusBp',
    'moveSpeedBonusBp',
    'cooldownReductionBp',
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
  ])
    key: const ItemField.number(0, min: -10000, max: 100000),
};
final _effectFields = <String, ItemField>{
  'magnitude': const ItemField.number(null),
  'durationSeconds': const ItemField.number(null, integer: false, max: 3600),
  'periodSeconds': const ItemField.number(
    null,
    integer: false,
    min: 0.000001,
    max: 3600,
  ),
  'scaleByDamageType': const ItemField.boolean(false),
  'dotDamageType': _damage,
  'resourceType': ItemField.choice(
    'StatusResourceType',
    StatusResourceType.values.map((v) => v.name).toList(),
    null,
  ),
  'critBonusBp': const ItemField.number(null, max: 10000),
  'applyOnApply': const ItemField.boolean(false),
};
final _tuning = ItemField.object('StatusProfileTuning', {
  for (final type in StatusEffectType.values)
    type.name: ItemField.object('StatusApplicationTuning', _effectFields),
});

/// Only applications supplied by Core's selected preset can be customized.
Map<String, ItemField> itemTuningFields(String profileId) {
  final profile = const StatusProfileCatalog().get(
    StatusProfileId.values.byName(profileId),
  );
  return {
    for (final application in profile.applications)
      application.type.name: _tuning.fields![application.type.name]!,
  };
}

Map<String, ItemField> _procFields(bool reactive) => {
  'hook': ItemField.choice(
    reactive ? 'ReactiveProcHook' : 'ProcHook',
    reactive
        ? ReactiveProcHook.values.map((v) => v.name).toList()
        : ProcHook.values.map((v) => v.name).toList(),
    reactive ? 'onDamaged' : 'onHit',
    required: true,
  ),
  'statusProfileId': ItemField.choice(
    'StatusProfileId',
    StatusProfileId.values
        .where((p) => p != StatusProfileId.none)
        .map((v) => v.name)
        .toList(),
    'slowOnHit',
    required: true,
  ),
  'chanceBp': const ItemField.number(10000, max: 10000),
  'statusTuning': _tuning,
  if (reactive) ...{
    'target': const ItemField.choice('ReactiveProcTarget', [
      'self',
      'attacker',
    ], 'self'),
    'lowHealthThresholdBp': const ItemField.number(3000, max: 10000),
    'internalCooldownTicks': const ItemField.number(0, max: 216000),
  },
};

Map<String, ItemField> itemFields(ItemCategory category) => {
  if (category == ItemCategory.weapon) ...{
    'category': const ItemField.choice(
      'WeaponCategory',
      ['primary', 'offHand'],
      'primary',
      required: true,
    ),
    'weaponType': _family,
    'damageType': _damage,
    'isTwoHanded': const ItemField.boolean(false),
  },
  if (category == ItemCategory.accessory)
    'slot': const ItemField.choice('AccessorySlot', ['trinket'], 'trinket'),
  if (category == ItemCategory.spellBook) ...{
    'weaponType': ItemField.choice('WeaponType', _family.choices, 'spell'),
    'damageType': ItemField.choice('DamageType', _damage.choices, null),
  },
  if (category == ItemCategory.projectile) ...{
    'weaponType': _family,
    'damageType': _damage,
    'speedUnitsPerSecond': const ItemField.number(
      600,
      integer: false,
      min: 0.000001,
      max: 10000,
      required: true,
    ),
    'lifetimeSeconds': const ItemField.number(
      1.3,
      integer: false,
      min: 0.000001,
      max: 60,
      required: true,
    ),
    'colliderSizeX': const ItemField.number(
      8,
      integer: false,
      min: 0.000001,
      max: 1000,
      required: true,
    ),
    'colliderSizeY': const ItemField.number(
      3,
      integer: false,
      min: 0.000001,
      max: 1000,
      required: true,
    ),
    'ballistic': const ItemField.boolean(false),
    'gravityScale': const ItemField.number(1.0, integer: false, max: 10),
    'shotCount': const ItemField.number(1, min: 1, max: 64),
    'spreadRadians': const ItemField.number(
      0.0,
      integer: false,
      max: 6.283185307179586,
    ),
    'damageScaleBp': const ItemField.number(10000, max: 100000),
  },
  'stats': ItemField.object('GearStatBonuses', itemStatFields),
  if (category != ItemCategory.accessory)
    'procs': ItemField.object('WeaponProc', _procFields(false), isList: true),
  if (category == ItemCategory.weapon || category == ItemCategory.accessory)
    'reactiveProcs': ItemField.object(
      'ReactiveProc',
      _procFields(true),
      isList: true,
    ),
};

void validateItemFields(
  Map<String, Object?> data,
  Map<String, ItemField> fields,
  String path,
) {
  _keys(data, fields.keys.toSet(), path);
  for (final e in fields.entries) {
    if (!data.containsKey(e.key)) {
      if (e.value.required) _fail('$path.${e.key}', 'A value is required.');
      continue;
    }
    final value = data[e.key], spec = e.value, fieldPath = '$path.${e.key}';
    if (spec.fields != null) {
      final values = spec.isList
          ? (value is List
                ? value
                : _fail(fieldPath, 'Expected an effect list.'))
          : [value];
      if (values.length > 32) {
        _fail(fieldPath, 'At most 32 effects are supported.');
      }
      for (var i = 0; i < values.length; i++) {
        final m = _object(values[i], fieldPath);
        validateItemFields(
          m,
          spec.fields!,
          spec.isList ? '$fieldPath[$i]' : fieldPath,
        );
        if (spec.constructor == 'WeaponProc' ||
            spec.constructor == 'ReactiveProc') {
          final profile = const StatusProfileCatalog().get(
            StatusProfileId.values.byName(m['statusProfileId'] as String),
          );
          final tuning = m['statusTuning'] as Map?;
          if (tuning != null &&
              tuning.keys.any(
                (k) => !profile.applications.any((a) => a.type.name == k),
              )) {
            _fail(
              fieldPath,
              'Tune only effects present in the selected status profile.',
            );
          }
        }
      }
    } else if (spec.choices != null) {
      if (value is! String || !spec.choices!.contains(value)) {
        _fail(fieldPath, 'Choose one of ${spec.choices!.join(', ')}.');
      }
    } else if (spec.defaultValue is bool) {
      if (value is! bool) _fail(fieldPath, 'Expected true or false.');
    } else if (value is! num ||
        !value.isFinite ||
        (spec.integer && value is! int) ||
        value < spec.min! ||
        value > spec.max!) {
      _fail(
        fieldPath,
        'Enter ${spec.integer ? 'an integer' : 'a finite number'} in [${spec.min}, ${spec.max}].',
      );
    }
  }
}

/// Emits only validated constructors/enums/numbers, never source-provided code.
String renderItemFields(
  Map<String, Object?> data,
  Map<String, ItemField> fields,
) => [
  for (final e in fields.entries)
    if (data.containsKey(e.key))
      '${e.key}: ${_renderField(data[e.key], e.value)},',
].join('\n');
String _renderField(Object? value, ItemField spec) {
  if (spec.fields != null) {
    String object(Object? v) =>
        '${spec.constructor}(${renderItemFields(_object(v, 'render'), spec.fields!)})';
    return spec.isList
        ? '[${(value as List).map(object).join(',')}]'
        : object(value);
  }
  return spec.enumType != null ? '${spec.enumType}.$value' : '$value';
}
