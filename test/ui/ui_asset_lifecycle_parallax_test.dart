import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/levels/level_assembly.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds parallax asset images from generated theme data', () async {
    final lifecycle = UiAssetLifecycle();
    addTearDown(lifecycle.dispose);

    final layers = await lifecycle.getParallaxLayers('forest');

    expect(layers.map((layer) => layer.assetName).toList(), <String>[
      'assets/images/parallax/forest/Forest Layer 01.png',
      'assets/images/parallax/forest/Forest Layer 02.png',
      'assets/images/parallax/forest/Forest Layer 03.png',
    ]);
  });

  test('collects level-scoped run theme ids regardless of assembly groups', () {
    final level = LevelRegistry.byId(LevelId.field).copyWith(
      assembly: const LevelAssemblyDefinition(
        loopSegments: true,
        segments: <LevelAssemblySegment>[
          LevelAssemblySegment(
            segmentId: 'forest_run',
            groupId: 'forest_group',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
          LevelAssemblySegment(
            segmentId: 'none_run',
            groupId: 'none_group',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
          LevelAssemblySegment(
            segmentId: 'default_run',
            groupId: 'field_group',
            minChunkCount: 1,
            maxChunkCount: 1,
            requireDistinctChunks: false,
          ),
        ],
      ),
    );

    expect(
      UiAssetLifecycle.reachableRunVisualThemeIdsForLevelDefinition(level),
      <String>['field'],
    );
  });

  test('field level authored assembly warms only the level visual theme', () {
    expect(
      UiAssetLifecycle.reachableRunVisualThemeIdsForLevelDefinition(
        LevelRegistry.byId(LevelId.field),
      ),
      <String>['field'],
    );
  });

  test('run-start warmup includes staged terrain material layers', () {
    final paths = UiAssetLifecycle.collectRunStartImagePathsForCharacter(
      PlayerCharacterRegistry.eloise.id,
    );

    expect(paths, contains('terrain/grass_dirt/fill.png'));
    expect(paths, contains('terrain/grass_dirt/surface.png'));
    expect(paths, contains('terrain/grass_dirt/foreground.png'));
    expect(paths, contains('terrain/grass_dirt/cap_left.png'));
    expect(paths, contains('terrain/grass_dirt/cap_right.png'));
  });
}
