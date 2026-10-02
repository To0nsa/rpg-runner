import 'package:image/image.dart' as image;
import 'package:rpg_runner/playtest.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/traps/trap_catalog.dart';
import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_render_catalog.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../terrain_materials/terrain_material_domain_models.dart';
import 'authored_playtest_preparation.dart';

/// Validates exact captured bytes off the UI isolate before a host can start.
Future<List<PlaytestPreparationIssue>> validateCapturedPlaytestAssets({
  required RunnerCapturedAssetBundle assets,
  required String materialContents,
  required Set<String> materialKeys,
  required Iterable<ChunkPattern> patterns,
}) async {
  final issues = <PlaytestPreparationIssue>[];
  final dimensions = <String, TerrainMaterialImageDimensions>{};
  for (final key in assets.assetKeys) {
    try {
      final data = await assets.load(key);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final authoredPng =
          key.startsWith('assets/images/level/') ||
          key.startsWith('assets/images/parallax/');
      final decoded = authoredPng
          ? image.decodePng(bytes)
          : image.decodeImage(bytes);
      if (decoded == null) {
        throw const FormatException('Image decoder returned no image.');
      }
      dimensions[key] = TerrainMaterialImageDimensions(
        width: decoded.width,
        height: decoded.height,
      );
    } on Object catch (error) {
      issues.add(
        PlaytestPreparationIssue(
          code: 'playtest_image_invalid',
          sourcePath: key,
          message: 'Captured image cannot be decoded: $error',
        ),
      );
    }
  }
  for (final id in WorldInteractionId.values) {
    final def = WorldInteractionRenderCatalog.get(id);
    for (final path in def.assetPaths) {
      final key = 'assets/images/$path';
      final size = dimensions[key];
      if (size == null ||
          def.source.x + def.source.width > size.width ||
          def.source.y + def.source.height > size.height) {
        issues.add(
          PlaytestPreparationIssue(
            code: 'playtest_interaction_art_invalid',
            sourcePath: key,
            message: 'Interaction animation requires every complete frame.',
          ),
        );
      }
    }
  }
  final catalog = decodeTerrainMaterialCatalog(
    materialContents,
    sourcePath: terrainMaterialDefsSourcePath,
  ).catalog!;
  for (final id in TrapId.values) {
    final key = 'assets/images/${TrapCatalog.get(id).assetPath}';
    final size = dimensions[key];
    if (size == null ||
        TrapCatalog.sourceRegions(id).any(
          (rect) =>
              rect.x + rect.width > size.width ||
              rect.y + rect.height > size.height,
        )) {
      issues.add(
        PlaytestPreparationIssue(
          code: 'playtest_trap_art_invalid',
          sourcePath: key,
          message:
              '${id.sourceKey} requires its complete reviewed sprite sheet, including dart impact frames.',
        ),
      );
    }
  }
  issues.addAll(
    validateTerrainMaterialImageDimensions(
      TerrainMaterialCatalog(
        materials: catalog.materials.where((m) => materialKeys.contains(m.key)),
      ),
      dimensionsFor: (path) => dimensions[path],
    ).map(
      (issue) => PlaytestPreparationIssue(
        code: issue.code,
        message: issue.message,
        sourcePath: issue.path,
        ownerKey: issue.materialKey,
      ),
    ),
  );
  for (final pattern in patterns) {
    for (final sprite in pattern.visualSprites) {
      final key = 'assets/images/${sprite.assetPath}';
      final size = dimensions[key];
      if (size == null) continue;
      if (sprite.srcX < 0 ||
          sprite.srcY < 0 ||
          sprite.srcX + sprite.srcWidth > size.width ||
          sprite.srcY + sprite.srcHeight > size.height) {
        issues.add(
          PlaytestPreparationIssue(
            code: 'playtest_sprite_region_out_of_bounds',
            sourcePath: key,
            ownerKey: pattern.chunkKey,
            message: 'A captured prefab sprite exceeds its image dimensions.',
          ),
        );
      }
    }
  }
  return issues;
}
