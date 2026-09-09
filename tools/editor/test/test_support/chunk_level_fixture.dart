import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:terrain_materials/terrain_materials.dart';

/// Disposable current-schema Level, Prefab, tile and material workspace.
/// Registers its cleanup with the test and begins with no authored Chunk owners.
Future<EditorWorkspace> createChunkLevelFixture({
  LevelDef level = standardChunkFixtureLevel,
}) async {
  final root = await Directory.systemTemp.createTemp('flat_starter_');
  addTearDown(() => root.deleteSync(recursive: true));
  final workspace = EditorWorkspace(rootPath: root.path);
  _write(workspace, levelDefsSourcePath, renderCanonicalLevelDefsJson([level]));
  _write(
    workspace,
    parallaxDefsSourcePath,
    renderCanonicalParallaxDefsJson([
      ParallaxThemeDef(
        parallaxThemeId: level.visualThemeId,
        revision: 1,
        layers: [],
      ),
    ]),
  );
  _write(
    workspace,
    'assets/authoring/level/prefab_defs.json',
    PrefabV3FileCodec.encode(PrefabV3FileData(slices: [], prefabs: [])),
  );
  _write(
    workspace,
    'assets/authoring/level/tile_defs.json',
    PrefabTileFileCodec.encode(
      PrefabTileFileData(tileSlices: [], platformModules: []),
    ),
  );
  const material = TerrainMaterialDefinition(
    key: 'grass_dirt',
    displayName: 'Grass',
    revision: 1,
    top: TerrainMaterialEdgeProfile(
      base: TerrainMaterialEdgeLayer(
        region: TerrainMaterialImageRegion(
          assetPath: 'assets/images/level/atlases/test/ground.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
        anchorY: 0,
      ),
    ),
    topStartCap: TerrainMaterialCap(
      region: TerrainMaterialImageRegion(
        assetPath: 'assets/images/level/atlases/test/ground.png',
        x: 0,
        y: 0,
        width: 16,
        height: 16,
      ),
      anchorX: 0,
      anchorY: 0,
    ),
    topEndCap: TerrainMaterialCap(
      region: TerrainMaterialImageRegion(
        assetPath: 'assets/images/level/atlases/test/ground.png',
        x: 0,
        y: 0,
        width: 16,
        height: 16,
      ),
      anchorX: 16,
      anchorY: 0,
    ),
    fill: TerrainMaterialImageRegion(
      assetPath: 'assets/images/level/atlases/test/ground.png',
      x: 0,
      y: 0,
      width: 16,
      height: 16,
    ),
  );
  _write(
    workspace,
    'assets/authoring/level/terrain_material_defs.json',
    TerrainMaterialCatalog(materials: [material]).toCanonicalJson(),
  );
  final atlas = File(workspace.resolve(material.fill.assetPath));
  atlas.parent.createSync(recursive: true);
  atlas.writeAsBytesSync(image.encodePng(image.Image(width: 16, height: 16)));
  return workspace;
}

void _write(EditorWorkspace workspace, String path, String contents) {
  final file = File(p.join(workspace.rootPath, path));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

const standardChunkFixtureLevel = LevelDef(
  levelId: 'forest',
  revision: 1,
  displayName: 'Forest',
  visualThemeId: 'forest',
  cameraCenterY: 135,
  groundTopY: 224,
  earlyPatternChunks: 3,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 3,
  enumOrdinal: 1,
  status: levelStatusActive,
);
