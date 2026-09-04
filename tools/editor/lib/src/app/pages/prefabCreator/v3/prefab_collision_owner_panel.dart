import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/platform_module_preview_tile.dart';
import '../shared/prefab_polygon_visual_source.dart';
import '../shared/prefab_visual_catalog_support.dart';
import 'prefab_collision_catalog.dart';
import 'prefab_owner_catalog_browser.dart';

/// Left sidebar for choosing collision owners and completing missing setup.
class PrefabCollisionOwnerPanel extends StatelessWidget {
  const PrefabCollisionOwnerPanel({
    super.key,
    required this.document,
    required this.selectedPrefab,
    required this.catalog,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.onPrefabSelected,
    required this.onEditPrefabCollision,
    required this.onEditPlatformCollision,
  });

  final PrefabV3Document document;
  final PrefabV3Def? selectedPrefab;
  final PrefabCollisionCatalog catalog;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final ValueChanged<PrefabV3Def> onPrefabSelected;
  final ValueChanged<String> onEditPrefabCollision;
  final ValueChanged<String> onEditPlatformCollision;

  bool get _selectedCanAuthorCollision =>
      selectedPrefab?.kind == PrefabKind.obstacle ||
      selectedPrefab?.kind == PrefabKind.platform;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey<String>('prefab_collision_owner_sidebar'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (catalog.unpairedModules.isNotEmpty ||
            catalog.prefabsNeedingCollision.isNotEmpty) ...[
          _CollisionSetupSection(
            document: document,
            modules: catalog.unpairedModules,
            prefabs: catalog.prefabsNeedingCollision,
            imageCache: imageCache,
            workspaceRootPath: workspaceRootPath,
            onEditPrefabCollision: onEditPrefabCollision,
            onEditPlatformCollision: onEditPlatformCollision,
          ),
          const SizedBox(height: EditorUiTokens.sectionGap),
        ],
        EditorSectionCard(
          key: const ValueKey<String>('prefab_collision_library_section'),
          expansionKey: const ValueKey<String>(
            'prefab_collision_library_section_toggle',
          ),
          title: 'Collision prefabs',
          description: 'Select an obstacle or platform to edit collision.',
          trailing: Text('${catalog.prefabs.length} total'),
          collapsible: true,
          initiallyExpanded: false,
          child: catalog.prefabs.isEmpty
              ? const Text(
                  'No obstacle or platform prefabs exist. Create one in '
                  'Prefabs first.',
                  key: ValueKey<String>('prefab_collision_library_empty'),
                )
              : PrefabOwnerCatalogBrowser(
                  prefabs: catalog.prefabs,
                  prefabData: document.data,
                  tileData: document.tileData,
                  visualBoundsByPrefabKey: document.visualBoundsByPrefabKey,
                  workspaceRootPath: workspaceRootPath,
                  selectedPrefabKey: _selectedCanAuthorCollision
                      ? selectedPrefab?.prefabKey
                      : null,
                  expandedPrefabKey: null,
                  changedPrefabKeys: document.changedPrefabKeys,
                  downstreamImpacts: document.downstreamImpacts,
                  enabled: true,
                  onSelected: onPrefabSelected,
                ),
        ),
      ],
    ),
  );
}

/// Empty center panel shown until a collision-capable Prefab is selected.
class PrefabCollisionEmptyScene extends StatelessWidget {
  const PrefabCollisionEmptyScene({super.key});

  @override
  Widget build(BuildContext context) => const EditorPanelCard(
    key: ValueKey<String>('prefab_collision_scene_empty'),
    title: 'Collision scene',
    bodyMode: EditorPanelBodyMode.expanded,
    child: Center(
      child: Text(
        'Create or select an obstacle or platform prefab to edit collision.',
      ),
    ),
  );
}

/// Empty inspector shown until a collision-capable Prefab is selected.
class PrefabCollisionEmptyInspector extends StatelessWidget {
  const PrefabCollisionEmptyInspector({super.key});

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    key: ValueKey<String>('prefab_collision_sidebar'),
    child: EditorSectionCard(
      title: 'Collision authoring',
      child: Text(
        'Collision shapes and diagnostics appear after selecting an obstacle '
        'or platform prefab.',
      ),
    ),
  );
}

class _CollisionSetupSection extends StatelessWidget {
  const _CollisionSetupSection({
    required this.document,
    required this.modules,
    required this.prefabs,
    required this.imageCache,
    required this.workspaceRootPath,
    required this.onEditPrefabCollision,
    required this.onEditPlatformCollision,
  });

  final PrefabV3Document document;
  final List<TileModuleDef> modules;
  final List<PrefabV3Def> prefabs;
  final EditorUiImageCache imageCache;
  final String workspaceRootPath;
  final ValueChanged<String> onEditPrefabCollision;
  final ValueChanged<String> onEditPlatformCollision;

  @override
  Widget build(BuildContext context) {
    final tileSlicesById = <String, AtlasSliceDef>{
      for (final slice in document.tileData.tileSlices) slice.id: slice,
    };
    return EditorSectionCard(
      key: const ValueKey<String>('prefab_collision_setup_section'),
      title: 'Collision setup needed',
      description:
          'Set up colliders for prefab visuals that are still non-colliding.',
      trailing: Text('${modules.length + prefabs.length} total'),
      collapsible: true,
      initiallyExpanded: false,
      expansionKey: const ValueKey<String>(
        'prefab_collision_setup_section_toggle',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final module in modules)
            EditorListCard(
              key: ValueKey<String>('prefab_unpaired_platform_${module.id}'),
              onTap: module.cells.isEmpty
                  ? null
                  : () => onEditPlatformCollision(module.id),
              semanticLabel:
                  '${module.id}, ${module.status.jsonValue}, collision not configured',
              preview: PlatformModulePreviewTile(
                imageCache: imageCache,
                workspaceRootPath: workspaceRootPath,
                module: module,
                tileSlicesById: tileSlicesById,
              ),
              trailing: IconButton.filledTonal(
                key: ValueKey<String>(
                  'prefab_unpaired_platform_setup_${module.id}',
                ),
                tooltip: module.cells.isEmpty
                    ? 'Add visual tiles first'
                    : 'Set up collision',
                onPressed: module.cells.isEmpty
                    ? null
                    : () => onEditPlatformCollision(module.id),
                icon: Icon(
                  module.cells.isEmpty
                      ? Icons.image_not_supported_outlined
                      : Icons.border_style_outlined,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(module.id),
                subtitle: Text(
                  '${module.status.jsonValue} · ${module.cells.length} visual '
                  'cell(s) · collision not configured',
                ),
              ),
            ),
          for (final prefab in prefabs)
            EditorListCard(
              key: ValueKey<String>(
                'prefab_missing_collision_${prefab.prefabKey}',
              ),
              onTap: () => onEditPrefabCollision(prefab.prefabKey),
              semanticLabel:
                  '${prefab.id}, ${prefab.kind.jsonValue}, '
                  '${prefab.status.jsonValue}, collision not configured',
              preview: SizedBox(
                width: 96,
                height: 76,
                child: PrefabCatalogThumbnail(
                  projection: PrefabPolygonVisualProjection.fromDocument(
                    document: document,
                    prefab: prefab,
                  ),
                  imageCache: imageCache,
                  workspaceRootPath: workspaceRootPath,
                ),
              ),
              trailing: IconButton.filledTonal(
                key: ValueKey<String>(
                  'prefab_missing_collision_setup_${prefab.prefabKey}',
                ),
                tooltip: 'Set up collision',
                onPressed: () => onEditPrefabCollision(prefab.prefabKey),
                icon: const Icon(Icons.border_style_outlined),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(prefab.id),
                subtitle: Text(
                  '${prefab.kind.jsonValue} prefab · '
                  '${prefab.status.jsonValue} · collision not configured',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
