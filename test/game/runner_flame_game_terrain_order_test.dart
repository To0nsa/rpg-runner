import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/contracts/render_contract.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/playtest/chunk_playtest_scenario.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:rpg_runner/game/components/pixel_parallax_backdrop.dart';
import 'package:rpg_runner/game/components/staged_terrain.dart';
import 'package:rpg_runner/game/components/static_prefab_sprite_component.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/runner_flame_game.dart';
import 'package:rpg_runner/game/themes/parallax_theme.dart';
import 'package:rpg_runner/game/themes/terrain_material_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final playtest in [false, true]) {
    testWidgets(
      '${playtest ? 'chunk playtest' : 'normal game'} renders prefab layers '
      'across terrain while the camera moves',
      (tester) async {
        final base = LevelRegistry.byId(LevelId.field);
        final original = base.chunkPatternSource.patternFor(
          seed: 42,
          chunkIndex: 0,
          tier: ChunkPatternTier.early,
        );
        final pattern = ChunkPattern(
          name: original.name,
          chunkKey: original.chunkKey,
          assemblyGroupId: original.assemblyGroupId,
          visualSprites: [
            for (final (index, z) in [-21, -1, 0, 1].indexed)
              ChunkVisualSpriteRel(
                assetPath: 'fixture_prefab.png',
                srcX: 0,
                srcY: 0,
                srcWidth: 1,
                srcHeight: 1,
                x: 96 + index * 40,
                y: base.groundTopY - 16,
                width: 24,
                height: 32,
                zIndex: z,
              ),
          ],
        );
        final level = base.copyWith(
          chunkPatternSource: ChunkPatternListSource(
            easyPatterns: const [],
            normalPatterns: [pattern],
          ),
        );
        final core = playtest
            ? GameCore.chunkPlaytest(
                scenario: ChunkPlaytestScenario(
                  terrainChunks: stagedAuthoredTerrain.chunks.where(
                    (chunk) => chunk.levelId == 'field',
                  ),
                  levelDefinition: level,
                  visualThemeId: 'fixture',
                  seed: 42,
                  draftPattern: pattern,
                  draftTerrain: stagedAuthoredTerrain.chunks.singleWhere(
                    (chunk) => chunk.chunkKey == pattern.chunkKey,
                  ),
                  playerCharacter: PlayerCharacterRegistry.eloise,
                  equippedLoadout: const EquippedLoadoutDef(),
                ),
              )
            : GameCore(
                seed: 42,
                levelDefinition: level.copyWith(visualThemeId: 'fixture'),
                playerCharacter: PlayerCharacterRegistry.eloise,
              );
        final controller = GameController(core: core);
        final aim = ValueNotifier(AimPreviewState.inactive);
        late _FixtureImages images;
        await tester.runAsync(() async {
          images = _FixtureImages(
            transparent: await _solidImage(const Color(0x00000000), 2048),
            prefab: await _solidImage(const Color(0xFFFF0000), 1),
            terrain: await _solidImage(const Color(0xFF00FF00), 1),
            background: await _solidImage(const Color(0xFF0000FF), 1),
          );
        });
        final game = RunnerFlameGame(
          controller: controller,
          input: RunnerInputRouter(controller: controller),
          projectileAimPreview: aim,
          meleeAimPreview: aim,
          playerCharacter: PlayerCharacterRegistry.eloise,
          imageCache: images,
          parallaxThemes: const {
            'fixture': ParallaxTheme(
              backgroundLayers: [
                PixelParallaxLayerSpec(
                  assetPath: 'fixture_background.png',
                  parallaxFactor: 0,
                ),
              ],
              foregroundLayers: [],
            ),
          },
          terrainMaterials: const {'grass_dirt': _terrainMaterial},
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          aim.dispose();
          images.dispose();
        });
        await tester.pumpWidget(GameWidget(game: game));
        for (var attempt = 0; attempt < 200; attempt++) {
          await tester.pump(const Duration(milliseconds: 25));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          expect(tester.takeException(), isNull);
          if (game.loadState.value.phase == RunLoadPhase.worldReady) {
            break;
          }
        }
        expect(game.loadState.value.phase, RunLoadPhase.worldReady);
        game.pauseEngine();
        game.onGameResize(
          Vector2(virtualWidth.toDouble(), virtualHeight.toDouble()),
        );

        final stagedTerrain = game.world.children
            .whereType<StagedTerrain>()
            .single;
        expect(stagedTerrain.debugAssetsReady, isTrue);
        expect(
          game.camera.backdrop.children.whereType<StagedTerrain>(),
          isEmpty,
        );
        expect(
          game.camera.backdrop.children
              .whereType<PixelParallaxBackdrop>()
              .single
              .isLoaded,
          isTrue,
        );
        expect(
          game.world.children.whereType<StaticPrefabSpriteComponent>().length,
          greaterThanOrEqualTo(4),
        );
        expect(
          game.world.children.whereType<StaticPrefabSpriteComponent>().every(
            (component) => component.isLoaded,
          ),
          isTrue,
        );

        for (final center in [
          Vector2(300, 135),
          Vector2(320, 142),
          Vector2(320.25, 142.5),
        ]) {
          game.camera.viewfinder.position = center;
          final recorder = ui.PictureRecorder();
          game.camera.renderTree(ui.Canvas(recorder));
          final picture = recorder.endRecording();
          await tester.runAsync(() async {
            final image = await picture.toImage(virtualWidth, virtualHeight);
            final pixels = (await image.toByteData())!;
            for (final sprite in pattern.visualSprites) {
              final x = (sprite.x + 12 - (center.x - virtualWidth / 2)).floor();
              for (final offsetY in [-8, 8]) {
                final y = (base.groundTopY + offsetY - (center.y - 135))
                    .floor();
                final offset = (y * virtualWidth + x) * 4;
                expect(
                  [
                    for (var channel = 0; channel < 4; channel++)
                      pixels.getUint8(offset + channel),
                  ],
                  offsetY < 0 || sprite.zIndex >= 0
                      ? [255, 0, 0, 255]
                      : [0, 255, 0, 255],
                  reason: 'z=${sprite.zIndex}, y=$offsetY, camera=$center',
                );
              }
            }
            image.dispose();
          });
          picture.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

const _terrainRegion = TerrainMaterialImageRegionSpec(
  assetPath: 'fixture_terrain.png',
  x: 0,
  y: 0,
  width: 1,
  height: 1,
);
const _terrainMaterial = TerrainMaterialSpec(
  key: 'grass_dirt',
  displayName: 'Fixture',
  revision: 1,
  fill: _terrainRegion,
  top: _terrainProfile,
  leftWall: _terrainProfile,
  rightWall: _terrainProfile,
  underside: _terrainProfile,
);
const _terrainProfile = TerrainMaterialEdgeProfileSpec(
  base: TerrainMaterialEdgeLayerSpec(region: _terrainRegion, anchorY: 0),
);

Future<ui.Image> _solidImage(Color color, int size) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(color, ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  return image;
}

class _FixtureImages extends Images {
  _FixtureImages({
    required this.transparent,
    required this.prefab,
    required this.terrain,
    required this.background,
  });

  final ui.Image transparent;
  final ui.Image prefab;
  final ui.Image terrain;
  final ui.Image background;

  @override
  Future<ui.Image> load(
    String fileName, {
    String? key,
    String? package,
  }) async => switch (fileName) {
    'fixture_prefab.png' => prefab,
    'fixture_terrain.png' => terrain,
    'fixture_background.png' => background,
    _ => transparent,
  };

  @override
  void clearCache() {}

  void dispose() {
    transparent.dispose();
    prefab.dispose();
    terrain.dispose();
    background.dispose();
  }
}
