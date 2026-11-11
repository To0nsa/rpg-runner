import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:runner_core/players/character_ability_namespace.dart';
import 'package:runner_core/players/character_equipment_policy.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';

import '../../tool/generate_backend_catalog.dart';

void main() {
  test('complete identities, slots and equipment eligibility match Core', () {
    final entries = backendCatalogEntries();
    final expected = <String, List<String>>{};
    void add(String domain, String slot, String itemId, String character) {
      expected.putIfAbsent('$domain/$slot/$itemId', () => []).add(character);
    }

    const service = MetaService();
    final meta = service.createNew();
    for (final character in PlayerCharacterRegistry.playable) {
      for (final slot in GearSlot.values) {
        for (final candidate in service.candidatesForSlot(
          meta,
          slot,
          characterId: character.id,
        )) {
          add(
            'gear',
            slot.name,
            (candidate.id as Enum).name,
            character.id.name,
          );
        }
      }
      for (final projectile in playerEquippableProjectileIds) {
        if (CharacterEquipmentPolicy.allowsProjectile(
          character.id,
          projectile,
        )) {
          add(
            'projectileSpell',
            'projectile',
            projectile.name,
            character.id.name,
          );
        }
      }
      for (final ability in AbilityCatalog.abilities.values) {
        final namespace = characterAbilityNamespace(character.id);
        if (!ability.id.startsWith('$namespace.') &&
            !(ability.id.startsWith('common.') &&
                !ability.id.startsWith('common.enemy_'))) {
          continue;
        }
        for (final slot in ability.allowedSlots) {
          add('ability', slot.name, ability.id, character.id.name);
        }
      }
    }
    expect({
      for (final e in entries)
        '${e['domain']}/${e['slot']}/${e['itemId']}': e['characterIds'],
    }, expected);
    expect(entries.length, expected.length);
    final hunterBlade = entries.singleWhere(
      (e) => e['itemId'] == 'hunterBlade',
    );
    expect(hunterBlade['characterIds'], ['bountyHunter']);
    // The same item is an account-wide reward; reward scope must not be used
    // to export equipment eligibility.
    expect(
      CatalogUnlock.fromJson({
        'kind': 'gear',
        'slot': 'mainWeapon',
        'itemId': 'hunterBlade',
      }).characterId,
      isNull,
    );
    expect(
      () => backendCatalogEntries(
        items: [CatalogItemId.values.first, CatalogItemId.values.first],
      ),
      throwsStateError,
    );
  });

  test('deterministic output preserves the existing gift order and activation hash', () {
    final rendered = renderBackendCatalog();
    expect(renderBackendCatalog(), rendered);
    expect(File(backendCatalogPath).readAsStringSync(), rendered);
    final fixture = jsonDecode(
      File('tools/admin/test/fixtures/catalog.json').readAsStringSync(),
    ) as Map;
    final entries = [
      for (final e in backendCatalogEntries())
        {'kind': e['domain'], 'slot': e['slot'], 'itemId': e['itemId']},
    ];
    final characters = PlayerCharacterRegistry.playable
        .map((c) => c.id.name)
        .toList();
    expect(entries, fixture['entries']);
    expect(characters, fixture['characters']);
    expect(
      sha256
          .convert(utf8.encode(jsonEncode([2, entries, characters])))
          .toString(),
      fixture['catalogHash'],
    );
    expect(
      rendered,
      contains(
        'export const coreAbilitySlots = ${const JsonEncoder.withIndent('  ').convert(AbilitySlot.values.map((s) => s.name).toList())}',
      ),
    );
  });

  test('CLI detects a real Core change without writing and rejects duplicate identities', () async {
    final root = Directory.systemTemp.createTempSync('backend_catalog_');
    addTearDown(() => root.deleteSync(recursive: true));
    for (final path in [
      'tool/generate_backend_catalog.dart',
      'tool/generated_artifact_plan.dart',
      backendCatalogPath,
    ]) {
      final target = File('${root.path}/$path');
      target.parent.createSync(recursive: true);
      File(path).copySync(target.path);
    }
    final core = Directory('packages/runner_core/lib');
    for (final file
        in core
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final target = File('${root.path}/${file.path}');
      target.parent.createSync(recursive: true);
      file.copySync(target.path);
    }
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in config['packages'] as List) {
      entry['rootUri'] = entry['name'] == 'runner_core'
          ? Directory('${root.path}/packages/runner_core').uri.toString()
          : configFile.absolute.uri
                .resolve(entry['rootUri'] as String)
                .toString();
    }
    final isolatedConfig = File('${root.path}/package_config.json')
      ..writeAsStringSync(jsonEncode(config));
    // flutter_tester is not the Dart CLI. Resolve the SDK from the package
    // configuration so this also works when CI does not export FLUTTER_ROOT.
    final flutter = (config['packages'] as List).singleWhere(
      (entry) => entry['name'] == 'flutter',
    );
    final flutterRoot = Directory.fromUri(
      Uri.parse(flutter['rootUri'] as String),
    ).parent.parent;
    final dart =
        '${flutterRoot.path}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
    Future<ProcessResult> run(List<String> args) => Process.run(dart, [
      '--packages=${isolatedConfig.path}',
      'tool/generate_backend_catalog.dart',
      ...args,
    ], workingDirectory: root.path);
    final output = File('${root.path}/$backendCatalogPath');
    final before = output.readAsBytesSync();
    final fresh = await run(['--check']);
    expect(fresh.exitCode, 0, reason: '${fresh.stdout}\n${fresh.stderr}');
    final source = File(
      '${root.path}/packages/runner_core/lib/projectiles/projectile_id.dart',
    );
    final original = source.readAsStringSync();
    source.writeAsStringSync(
      original.replaceFirst('  ProjectileId.thunderBolt,', ''),
    );
    final stale = await run(['--check']);
    expect(stale.exitCode, 1, reason: '${stale.stdout}\n${stale.stderr}');
    expect(stale.stderr, contains('generated_output_stale'));
    expect(output.readAsBytesSync(), before);
    final generated = await run([]);
    expect(
      generated.exitCode,
      0,
      reason: '${generated.stdout}\n${generated.stderr}',
    );
    final changed = output.readAsBytesSync();
    expect(changed, isNot(before));
    expect((await run(['--check'])).exitCode, 0);
    expect((await run([])).exitCode, 0);
    expect(output.readAsBytesSync(), changed);
    source.writeAsStringSync(
      original.replaceFirst(
        '  ProjectileId.thunderBolt,',
        '  ProjectileId.thunderBolt,\n  ProjectileId.thunderBolt,',
      ),
    );
    final duplicate = await run([]);
    expect(duplicate.exitCode, 1);
    expect(duplicate.stderr, contains('Duplicate catalogue identity'));
    expect(output.readAsBytesSync(), changed);
    source.writeAsStringSync(original);
    final abilities = File(
      '${root.path}/packages/runner_core/lib/abilities/catalog/eloise_ability_defs.dart',
    );
    final originalAbilities = abilities.readAsStringSync();
    abilities.writeAsStringSync(
      originalAbilities.replaceFirst(
        "id: 'eloise.bloodletter_slash'",
        "id: 'eloise.unsupported'",
      ),
    );
    final unsupported = await run([]);
    expect(unsupported.exitCode, 1);
    expect(unsupported.stderr, contains('does not match AbilityDef.id'));
    expect(output.readAsBytesSync(), changed);
    abilities.writeAsStringSync(originalAbilities);
    final registry = File(
      '${root.path}/packages/runner_core/lib/abilities/ability_catalog.dart',
    );
    registry.writeAsStringSync(
      registry.readAsStringSync().replaceFirst(
        '      eloiseAbilityDefs,',
        '      eloiseAbilityDefs,\n      eloiseAbilityDefs,',
      ),
    );
    final duplicateAbility = await run([]);
    expect(duplicateAbility.exitCode, 1);
    expect(duplicateAbility.stderr, contains('Duplicate AbilityDef.id'));
    expect(output.readAsBytesSync(), changed);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
