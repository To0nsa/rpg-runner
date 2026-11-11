import 'dart:convert';
import 'dart:io';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/character_equipment_policy.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_id.dart';

import 'generated_artifact_plan.dart';

const backendCatalogPath = 'functions/src/ownership/core_catalog.generated.ts';

Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check')) {
    stderr.writeln(
      'Usage: dart run tool/generate_backend_catalog.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  try {
    final sources = await _sourceBytes();
    final plan = GeneratedArtifactPlan([
      GeneratedArtifact(
        path: backendCatalogPath,
        content: renderBackendCatalog(),
      ),
    ]);
    Future<void> verifySources() async {
      if (jsonEncode(sources) != jsonEncode(await _sourceBytes())) {
        throw StateError(
          'Core catalogue source changed during generation. Retry.',
        );
      }
    }

    await verifySources();
    final drift = await plan.inspectDrift();
    if (args.contains('--check')) {
      for (final issue in drift) {
        stderr.writeln('${issue.code}: ${issue.path}');
      }
      if (drift.isNotEmpty) {
        stderr.writeln('Run dart run tool/generate_backend_catalog.dart');
        exitCode = 1;
      }
    } else if (drift.isNotEmpty) {
      await plan.writeAll(beforeReplacement: verifySources);
    }
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<Map<String, String>> _sourceBytes() async {
  final paths = [
    'tool/generate_backend_catalog.dart',
    'tool/generated_artifact_plan.dart',
    await for (final entry in Directory(
      'packages/runner_core/lib',
    ).list(recursive: true, followLinks: false))
      if (entry is File && entry.path.endsWith('.dart')) entry.path,
  ]..sort();
  return {
    for (final path in paths)
      path: base64Encode(await File(path).readAsBytes()),
  };
}

/// Exports identities and equipment eligibility only; gift ownership scope is
/// deliberately separate. Optional items allow validation of malformed sources.
List<Map<String, Object>> backendCatalogEntries({
  Iterable<CatalogItemId>? items,
}) {
  final characters = PlayerCharacterRegistry.playable;
  if (characters.isEmpty ||
      characters.map((c) => c.id).toSet().length != characters.length) {
    throw StateError('Empty or duplicate playable character identities.');
  }
  final keys = <String>{};
  final result = <Map<String, Object>>[];
  for (final item in items ?? CatalogItemId.values) {
    if (!keys.add(item.key)) {
      throw StateError('Duplicate catalogue identity: ${item.key}');
    }
    if (item.itemId.length > 100 ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_.]*$').hasMatch(item.itemId)) {
      throw StateError('Unsupported catalogue identity: ${item.key}');
    }
    // Resolve the actual definition, never a rendering/presentation fallback.
    final resolvedId = switch ((item.kind, item.gearId)) {
      ('gear', final WeaponId id) => const WeaponCatalog().get(id).id.name,
      ('gear', final SpellBookId id) =>
        const SpellBookCatalog().get(id).id.name,
      ('gear', final AccessoryId id) =>
        const AccessoryCatalog().get(id).id.name,
      ('projectileSpell', _) =>
        const ProjectileCatalog().get(item.projectileId!).id.name,
      ('ability', _) => AbilityCatalog.abilities[item.itemId]?.id,
      _ => null,
    };
    if (resolvedId != item.itemId) {
      throw StateError('Unsupported catalogue definition: ${item.key}');
    }
    final characterIds = [
      for (final character in characters)
        if (item.kind == 'gear'
            ? CharacterEquipmentPolicy.allowsGear(
                character.id,
                item.gearSlot!,
                item.gearId!,
              )
            : item.supportsCharacter(character.id.name))
          character.id.name,
    ];
    if (characterIds.isEmpty) {
      throw StateError('No eligible character for ${item.key}');
    }
    result.add({
      'domain': item.kind,
      'slot': item.slot,
      'itemId': item.itemId,
      'characterIds': characterIds,
    });
  }

  // Schema-2 gift activation hashes include array order. Preserve the original
  // layout through category/registry order, with no parallel item-ID allowlist:
  // expansion-exclusive gear/skills, baseline gear, all projectiles, baseline
  // spell skills, then baseline combat skills. Within slots use Core declaration
  // order. The ordinal tie-break also makes ordering stable on every platform.
  final indexed = result.indexed.toList();
  (int, int) order(Map<String, Object> entry) {
    final eligible = entry['characterIds']! as List<String>;
    final domain = entry['domain'];
    final slot = entry['slot'];
    int slotIndex(List<String> slots) {
      final index = slots.indexOf(slot as String);
      if (index < 0) {
        throw StateError('Unsupported backend slot: $domain/$slot');
      }
      return index;
    }

    final expansion = !eligible.contains(characters.first.id.name);
    if (domain != 'projectileSpell' && expansion) {
      final owner = characters.indexWhere((c) => eligible.contains(c.id.name));
      final slots = domain == 'gear'
          ? ['mainWeapon', 'offhandWeapon', 'spellBook', 'accessory']
          : ['primary', 'secondary', 'projectile', 'mobility', 'jump', 'spell'];
      return (owner * 2 + (domain == 'gear' ? 0 : 1), slotIndex(slots));
    }
    final base = characters.length * 2;
    if (domain == 'gear') {
      return (
        base,
        slotIndex(['mainWeapon', 'offhandWeapon', 'accessory', 'spellBook']),
      );
    }
    if (domain == 'projectileSpell') return (base + 1, 0);
    return (
      base + 2,
      slotIndex([
        'spell',
        'primary',
        'secondary',
        'projectile',
        'mobility',
        'jump',
      ]),
    );
  }

  indexed.sort((a, b) {
    final left = order(a.$2), right = order(b.$2);
    final section = left.$1.compareTo(right.$1);
    if (section != 0) return section;
    final slot = left.$2.compareTo(right.$2);
    return slot != 0 ? slot : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}

/// Pure rendering keeps check mode byte-for-byte and free of repository writes.
String renderBackendCatalog() {
  final entries = backendCatalogEntries();
  final characters = PlayerCharacterRegistry.playable;
  final meta = const MetaService().createNew();
  final loadouts = {
    for (final character in characters)
      character.id.name: {
        'mask': character.catalog.loadoutSlotMask,
        ...CharacterEquipmentPolicy.defaults(character.id).toJson(),
        'projectileSlotSpellId': character.catalog.projectileSlotSpellId.name,
        'abilityPrimaryId': character.catalog.abilityPrimaryId,
        'abilitySecondaryId': character.catalog.abilitySecondaryId,
        'abilityProjectileId': character.catalog.abilityProjectileId,
        'abilitySpellId': character.catalog.abilitySpellId,
        'abilityMobilityId': character.catalog.abilityMobilityId,
        'abilityJumpId': character.catalog.abilityJumpId,
      },
  };
  for (final character in characters) {
    final id = character.id.name;
    void requireItem(String domain, String slot, Object? itemId) {
      if (!entries.any(
        (e) =>
            e['domain'] == domain &&
            e['slot'] == slot &&
            e['itemId'] == itemId &&
            (e['characterIds']! as List<String>).contains(id),
      )) {
        throw StateError(
          'Invalid starter reference: $id/$domain/$slot/$itemId',
        );
      }
    }

    for (final slot in GearSlot.values) {
      requireItem('gear', slot.name, loadouts[id]!['${slot.name}Id']);
    }
    requireItem(
      'projectileSpell',
      'projectile',
      loadouts[id]!['projectileSlotSpellId'],
    );
    final ownership = meta.abilityOwnershipFor(character.id);
    for (final projectile in ownership.learnedProjectileSpellIds) {
      requireItem('projectileSpell', 'projectile', projectile.name);
    }
    for (final slot in AbilitySlot.values) {
      final field =
          'ability${slot.name[0].toUpperCase()}${slot.name.substring(1)}Id';
      requireItem('ability', slot.name, loadouts[id]![field]);
      for (final ability in ownership.learnedAbilityIdsForSlot(slot)) {
        requireItem('ability', slot.name, ability);
      }
    }
  }
  const json = JsonEncoder.withIndent('  ');
  return '''// GENERATED by tool/generate_backend_catalog.dart. Do not edit.
// Core owns identities/eligibility/starters; Functions owns economy and grants.
import type { JsonObject } from "./contracts.js";

export const coreCharacterIds = ${json.convert(characters.map((c) => c.id.name).toList())} as const;
export const coreGearSlots = ${json.convert(GearSlot.values.map((s) => s.name).toList())} as const;
export const coreAbilitySlots = ${json.convert(AbilitySlot.values.map((s) => s.name).toList())} as const;

export const coreCatalog = [
${entries.map((entry) => '  ${jsonEncode(entry)},').join('\n')}
] as const;

export const coreStarterLoadouts: Record<(typeof coreCharacterIds)[number], JsonObject> = ${json.convert(loadouts)};
export const coreStarterMeta: JsonObject = ${json.convert(meta.toJson())};
''';
}
