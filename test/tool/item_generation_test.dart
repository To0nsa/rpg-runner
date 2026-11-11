@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_content_pipeline/item_source.dart';

import '../../tool/item_generation.dart';
import '../../tool/generate_backend_catalog.dart';

void main() {
  final source = File(itemSourcePath).readAsStringSync();
  test('source compilation preserves existing backend ordering and bytes', () {
    final catalog = ItemCatalogSource.decode(source);
    expect(
      renderBackendCatalog(authoredItems: catalog.items),
      renderBackendCatalog(),
    );
    expect(
      buildItemArtifacts(catalog).map((a) => a.content),
      buildItemArtifacts(catalog).map((a) => a.content),
    );
  });
  test('generation rejects deletion, ordinal/family changes and invalid references', () {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final items = root['items'] as List;
    items[0]['data']['weaponType'] = 'hunterBlade';
    expect(
      () => buildItemArtifacts(ItemCatalogSource.decode(jsonEncode(root))),
      throwsFormatException,
    );
    items[0]['data']['weaponType'] = 'oneHandedSword';
    items[0]['icon'] = 'notAnIcon';
    expect(
      () => buildItemArtifacts(ItemCatalogSource.decode(jsonEncode(root))),
      throwsFormatException,
    );
    items[0]['icon'] = 'plainsteel';
    items.removeAt(0);
    expect(
      () => buildItemArtifacts(ItemCatalogSource.decode(jsonEncode(root))),
      throwsFormatException,
    );
  });
  test('new items compile into Core, shared names/icons and backend without hand-maintained IDs; check is read-only', () async {
    final fixture = Directory.systemTemp.createTempSync('item_generation_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    void write(String path, String content) {
      final file = File('${fixture.path}/$path');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    for (final directory in [
      'packages/runner_core/lib',
      'packages/game_presentation/lib',
      'packages/runner_content_pipeline/lib',
    ]) {
      for (final file
          in Directory(directory)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        write(file.path, file.readAsStringSync());
      }
    }
    for (final path in [
      'tool/generate_item_data.dart',
      'tool/item_generation.dart',
      'tool/generated_artifact_plan.dart',
      'tool/content_build_report.dart',
      'tool/generate_backend_catalog.dart',
      backendCatalogPath,
    ]) {
      write(path, File(path).readAsStringSync());
    }
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in config['packages'] as List) {
      entry['rootUri'] =
          ['runner_core', 'game_presentation'].contains(entry['name'])
          ? Directory('${fixture.path}/packages/${entry['name']}').uri
                .toString()
          : configFile.uri.resolve(entry['rootUri'] as String).toString();
    }
    (config['packages'] as List).add({
      'name': 'item_generation_fixture',
      'rootUri': fixture.uri.toString(),
      'packageUri': 'lib/',
      'languageVersion': '3.13',
    });
    write('.dart_tool/package_config.json', jsonEncode(config));
    final graph = jsonDecode(
      File('.dart_tool/package_graph.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    graph['roots'] = ['item_generation_fixture'];
    (graph['packages'] as List).add({
      'name': 'item_generation_fixture',
      'version': '1.0.0',
      'dependencies': ['flutter', 'game_presentation'],
      'devDependencies': ['flutter_test'],
    });
    write('.dart_tool/package_graph.json', jsonEncode(graph));
    write(
      'pubspec.yaml',
      'name: item_generation_fixture\nversion: 1.0.0\nenvironment:\n  sdk: ^3.13.1\ndependencies:\n  flutter:\n    sdk: flutter\ndev_dependencies:\n  flutter_test:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
    );
    for (final name in [
      'runner_core',
      'game_presentation',
      'runner_content_pipeline',
    ]) {
      write(
        'packages/$name/pubspec.yaml',
        File('packages/$name/pubspec.yaml').readAsStringSync(),
      );
    }
    final flutter = (config['packages'] as List).singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final flutterRoot = Directory.fromUri(
      Uri.parse(flutter['rootUri'] as String),
    ).parent.parent.path;
    final dart =
        '$flutterRoot/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
    Future<ProcessResult> run(String script, [List<String> args = const []]) =>
        Process.run(dart, [
          '--packages=${fixture.path}/.dart_tool/package_config.json',
          script,
          ...args,
        ], workingDirectory: fixture.path);
    final catalog = ItemCatalogSource.decode(source);
    final json = catalog.toJson(),
        rows = catalog.items.map((i) => i.toJson()).toList();
    for (final category in ItemCategory.values) {
      final template = catalog.items.firstWhere(
        (i) =>
            i.category == category &&
            (category != ItemCategory.projectile || i.id == 'hunterCrossbow'),
      );
      final row = template.toJson()
        ..['id'] = 'new${category.name}'
        ..['name'] = {
          'en': 'New ${category.name}',
          'fr': 'Nouveau ${category.name}',
        };
      final ordinals = [
        for (final i in catalog.items)
          if (i.category == category) i.ordinal,
        if (category == ItemCategory.projectile)
          ...catalog.internalProjectiles.keys,
      ]..sort();
      row['ordinal'] = ordinals.last + 1;
      rows.add(row);
    }
    json['items'] = rows;
    write(itemSourcePath, ItemCatalogSource.decode(jsonEncode(json)).encode());
    final stale = await run('tool/generate_item_data.dart', ['--check']);
    expect(stale.exitCode, 1, reason: '${stale.stdout}\n${stale.stderr}');
    expect(
      File('${fixture.path}/$backendCatalogPath').readAsStringSync(),
      File(backendCatalogPath).readAsStringSync(),
    );
    expect(
      File('${fixture.path}/packages/runner_core/lib/weapons/weapon_id.dart')
          .readAsStringSync(),
      isNot(contains('newweapon')),
    );
    final built = await run('tool/generate_item_data.dart');
    expect(built.exitCode, 0, reason: '${built.stdout}\n${built.stderr}');
    final output = File('${fixture.path}/$backendCatalogPath')
        .readAsStringSync();
    expect(output, contains('newweapon'));
    final checked = await run('tool/generate_item_data.dart', ['--check']);
    expect(checked.exitCode, 0, reason: '${checked.stdout}\n${checked.stderr}');
    expect((await run('tool/generate_item_data.dart')).exitCode, 0);
    expect(
      File('${fixture.path}/$backendCatalogPath').readAsStringSync(),
      output,
    );
    final backend = await run('tool/generate_backend_catalog.dart', [
      '--check',
    ]);
    expect(backend.exitCode, 0, reason: '${backend.stdout}\n${backend.stderr}');
    write('probe.dart', r'''
import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:game_presentation/items.generated.dart';
void main() {
  for(final category in ['weapon','accessory','spellBook','projectile']) {
    if(!CatalogItemId.values.any((i)=>i.itemId=='new$category'))throw StateError('Missing picker identity: $category');
    if(authoredItemName(category,'new$category','fr')!='Nouveau $category')throw StateError('Missing translation');
  }
  final id=ProjectileId.values.byName('newprojectile');
  if(const ProjectileCatalog().get(id).id!=id)throw StateError('Wrong typed definition');
  if(itemIconForProjectile(id)!.name!='hunterCrossbow')throw StateError('Wrong canonical icon');
  if(const ProjectileRenderCatalog().get(id)!=const ProjectileRenderCatalog().get(ProjectileId.hunterCrossbow))throw StateError('Missing renderer');
  final c=PlayerCharacterRegistry.bountyHunter;
  if(c.projectileMuzzles[id]==null || !c.renderVariants.containsKey(id))throw StateError('Missing muzzle/character art');
}
''');
    final probe = await run('probe.dart');
    expect(probe.exitCode, 0, reason: '${probe.stdout}\n${probe.stderr}');
    // Both campaign rewards and Admin compose this exact shared picker. Exercise
    // it against the newly compiled enums and the actual generated backend rows.
    write('picker_test.dart', r'''
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/catalog_item.dart';
import 'package:game_presentation/catalog_gift_picker.dart';
import 'package:game_presentation/catalog_gift.dart';
class RepositoryBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key.startsWith('assets/')
    ? SynchronousFuture(ByteData.sublistView(File('${Platform.environment['ITEM_REPOSITORY']}/$key').readAsBytesSync()))
    : rootBundle.load(key);
}
void main() {
  testWidgets('new identities reach campaign and Admin shared pickers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final path = Platform.environment['ITEM_FIXTURE']!;
    final text = File('$path/functions/src/ownership/core_catalog.generated.ts').readAsStringSync();
    final start = text.indexOf('[', text.indexOf('export const coreCatalog ='));
    final end = text.indexOf('] as const', start);
    final rows = jsonDecode(text.substring(start, end + 1).replaceFirst(RegExp(r',\s*]$'), ']')) as List;
    final backendItems = rows.map((r) => GameCatalogItem.fromJson({
      'kind': r['domain'], 'slot': r['slot'], 'itemId': r['itemId'],
    })).toList();
    for (final catalog in [GameCatalogItem.values, backendItems]) {
      final selected = <CatalogGift>[];
      await tester.pumpWidget(DefaultAssetBundle(bundle: RepositoryBundle(), child: MaterialApp(home: Scaffold(body: CatalogGiftPicker(
        key: UniqueKey(), catalog: catalog, characters: const ['bountyHunter'],
        selected: selected, onToggle: selected.add,
      )))));
      for (final category in ['weapon','accessory','spellBook','projectile']) {
        await tester.enterText(find.byKey(const Key('catalog-search')), 'new$category');
        await tester.pumpAndSettle();
        expect(find.text('New $category'), findsOneWidget);
        await tester.tap(find.text('New $category'));
        await tester.pump();
        expect(selected.last.item.itemId, 'new$category');
      }
      expect(tester.takeException(), isNull);
    }
  });
}
''');
    final picker = await Process.run(
      dart,
      [
        '$flutterRoot/bin/cache/flutter_tools.snapshot',
        'test',
        '--no-pub',
        '--reporter=expanded',
        '--packages=${fixture.path}/.dart_tool/package_config.json',
        '${fixture.path}/picker_test.dart',
      ],
      workingDirectory: fixture.path,
      environment: {
        'ITEM_FIXTURE': fixture.path,
        'ITEM_REPOSITORY': Directory.current.path,
      },
    );
    expect(picker.exitCode, 0, reason: '${picker.stdout}\n${picker.stderr}');
  });
}
