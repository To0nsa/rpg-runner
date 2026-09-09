import 'package:runner_core/playtest/playtest_scenario.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import '../game/components/enemies/enemy_render_registry.dart';
import '../game/components/projectiles/projectile_render_registry.dart';
import '../game/components/pickups/pickup_render_registry.dart';
import '../game/components/spell_impacts/spell_impact_render_registry.dart';
import '../game/themes/parallax_theme.dart';
import '../game/themes/terrain_material_registry.dart';

export '../game/themes/parallax_theme.dart';
export '../game/themes/terrain_material_registry.dart' show TerrainMaterialSpec;
export '../game/themes/terrain_material_source.dart';
export '../game/components/pixel_parallax_backdrop.dart'
    show PixelParallaxLayerSpec;

/// Captured appearance shared by whole-Level and focused Chunk hosts.
final class RunnerPlaytestAppearance {
  RunnerPlaytestAppearance({
    required Map<String, ParallaxTheme> parallaxThemes,
    required Map<String, TerrainMaterialSpec> terrainMaterials,
  }) : parallaxThemes = Map<String, ParallaxTheme>.unmodifiable({
         for (final entry in parallaxThemes.entries)
           entry.key: ParallaxTheme(
             backgroundLayers: List.unmodifiable(entry.value.backgroundLayers),
             foregroundLayers: List.unmodifiable(entry.value.foregroundLayers),
           ),
       }),
       terrainMaterials = Map<String, TerrainMaterialSpec>.unmodifiable(
         terrainMaterials,
       );

  final Map<String, ParallaxTheme> parallaxThemes;
  final Map<String, TerrainMaterialSpec> terrainMaterials;

  /// Sources read by the real renderer, including later streamed Prefab uses.
  Set<String> requiredAssetKeys({
    required PlaytestScenario scenario,
    required Iterable<ChunkPattern> patterns,
  }) => {
    for (final path in <String>[
      ...scenario.playerCharacter.renderAnim.sourcesByKey.values,
      ...EnemyRenderRegistry().assetPaths,
      ...ProjectileRenderRegistry().assetPaths,
      ...PickupRenderRegistry().assetPaths,
      ...SpellImpactRenderRegistry().assetPaths,
      for (final theme in parallaxThemes.values)
        for (final layer in theme.backgroundLayers) layer.assetPath,
      for (final material in terrainMaterials.values) ...material.assetPaths,
      for (final pattern in patterns)
        for (final sprite in pattern.visualSprites) sprite.assetPath,
    ])
      'assets/images/$path',
  };
}
