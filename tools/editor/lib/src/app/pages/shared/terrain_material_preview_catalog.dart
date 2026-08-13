import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Surface semantics currently consumed by terrain placement and navigation.
const List<String> terrainSurfaceKindOptions = <String>[
  'ground',
  'obstacle',
];

/// Workspace-relative textures and render alignment for one terrain material.
@immutable
final class TerrainMaterialPreviewAssets {
  const TerrainMaterialPreviewAssets({
    required this.materialKey,
    required this.fillAssetPath,
    required this.surfaceAssetPath,
    required this.foregroundAssetPath,
    required this.surfaceAnchorY,
  });

  final String materialKey;
  final String fillAssetPath;
  final String surfaceAssetPath;
  final String foregroundAssetPath;

  /// Vertical surface-texture anchor in logical pixels.
  final double surfaceAnchorY;
}

/// Visual asset projection for terrain material keys exposed by the editor.
///
/// The editor is a standalone package, so it cannot import the app's runtime
/// registry. Keep this read-only projection aligned when a runtime terrain
/// material is introduced; source polygons remain gameplay authority.
/// TODO(rpg_runner): replace this projection with an authored material manifest
/// when terrain-material authoring becomes a supported editor domain.
const List<TerrainMaterialPreviewAssets> terrainMaterialPreviewCatalog =
    <TerrainMaterialPreviewAssets>[
      TerrainMaterialPreviewAssets(
        materialKey: 'grass_dirt',
        fillAssetPath: 'assets/images/terrain/grass_dirt/fill.png',
        surfaceAssetPath: 'assets/images/terrain/grass_dirt/surface.png',
        foregroundAssetPath:
            'assets/images/terrain/grass_dirt/foreground.png',
        surfaceAnchorY: 12,
      ),
    ];

/// Resolves one registered preview material after trimming its source key.
TerrainMaterialPreviewAssets? terrainMaterialPreviewAssetsForKey(
  String? materialKey,
) {
  final normalized = materialKey?.trim();
  for (final material in terrainMaterialPreviewCatalog) {
    if (material.materialKey == normalized) return material;
  }
  return null;
}

/// Shows the source textures that compose one terrain material.
///
/// Missing files remain a visible authoring warning and do not affect source
/// editing or validation.
class TerrainMaterialAssetPreview extends StatelessWidget {
  const TerrainMaterialAssetPreview({
    super.key,
    required this.workspaceRootPath,
    required this.materialKey,
    required this.keyPrefix,
  });

  final String workspaceRootPath;
  final String? materialKey;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final material = terrainMaterialPreviewAssetsForKey(materialKey);
    if (material == null) {
      return Text(
        materialKey == null
            ? 'No material selected.'
            : 'No preview assets are registered for $materialKey.',
        key: ValueKey<String>('${keyPrefix}_material_preview_empty'),
      );
    }
    return Column(
      key: ValueKey<String>('${keyPrefix}_material_preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${material.materialKey} assets'),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TerrainMaterialAssetTile(
                workspaceRootPath: workspaceRootPath,
                label: 'Fill',
                sourcePath: material.fillAssetPath,
                tileKey: '${keyPrefix}_material_preview_fill',
              ),
              const SizedBox(width: 8),
              _TerrainMaterialAssetTile(
                workspaceRootPath: workspaceRootPath,
                label: 'Surface',
                sourcePath: material.surfaceAssetPath,
                tileKey: '${keyPrefix}_material_preview_surface',
              ),
              const SizedBox(width: 8),
              _TerrainMaterialAssetTile(
                workspaceRootPath: workspaceRootPath,
                label: 'Foreground',
                sourcePath: material.foregroundAssetPath,
                tileKey: '${keyPrefix}_material_preview_foreground',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TerrainMaterialAssetTile extends StatelessWidget {
  const _TerrainMaterialAssetTile({
    required this.workspaceRootPath,
    required this.label,
    required this.sourcePath,
    required this.tileKey,
  });

  final String workspaceRootPath;
  final String label;
  final String sourcePath;
  final String tileKey;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(
                File(p.normalize(p.join(workspaceRootPath, sourcePath))),
                key: ValueKey<String>(tileKey),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Tooltip(
          message: sourcePath,
          child: Text(
            p.basename(sourcePath),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
