import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_plugin.dart';
import '../../../entities/entity_domain_plugin.dart';
import '../../../levels/level_domain_plugin.dart';
import '../../../parallax/parallax_domain_plugin.dart';
import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_materials/terrain_material_domain_plugin.dart';
import '../chunkCreator/chunk_creator_page.dart';
import '../entities/entities_editor_page.dart';
import '../levelCreator/level_creator_page.dart';
import '../parallaxEditor/parallax_editor_page.dart';
import '../prefabCreator/prefab_creator_page.dart';
import '../terrainMaterials/terrain_materials_page.dart';

/// Defines one top-level page shown in the editor home shell.
///
/// This is the single source of truth for route identity, selector label,
/// plugin/session mapping, and page construction. Adding a new top-level
/// authoring domain should start here so the selector, session plugin switch,
/// and rendered page stay in sync.
class EditorHomeRoute {
  const EditorHomeRoute({
    required this.id,
    required this.label,
    required this.pluginId,
    required this.buildPage,
  });

  /// Stable route id used by the home page to track selection.
  final String id;

  /// User-facing label shown in the home selector.
  final String label;

  /// Plugin id that must become active when this route is selected.
  final String pluginId;

  /// Builds the route page with the shared session controller and stable page
  /// key owned by the home shell.
  final Widget Function({
    required GlobalKey key,
    required EditorSessionController controller,
    required EditorHomeRouteNavigation navigation,
  })
  buildPage;
}

/// Shell-owned navigation capabilities exposed to domain route pages.
///
/// Domain pages can request a guarded transition without owning route or
/// plugin-session state. The optional prefab key is consumed only by the
/// Prefab-v3 surface as its initial stable owner selection.
@immutable
class EditorHomeRouteNavigation {
  const EditorHomeRouteNavigation({
    this.initialPrefabKey,
    this.onOpenOwningPrefab,
  });

  /// Stable Prefab-v3 owner to select after a successful guarded transition.
  final String? initialPrefabKey;

  /// Requests shell-owned navigation to a placed collision's source owner.
  final ValueChanged<String>? onOpenOwningPrefab;
}

const String entitiesRouteId = 'entities';
const String prefabCreatorRouteId = 'prefab_creator';
const String chunkCreatorRouteId = 'chunk_creator';
const String levelCreatorRouteId = 'level_creator';
const String parallaxEditorRouteId = 'parallax_editor';
const String terrainMaterialsRouteId = 'terrain_materials';

/// Ordered top-level routes shown by the home page selector.
///
/// Keep this list authoritative: selector order, plugin switching, and page
/// creation all derive from these entries.
final List<EditorHomeRoute> homeRoutes = <EditorHomeRoute>[
  EditorHomeRoute(
    id: entitiesRouteId,
    label: 'Entities',
    pluginId: EntityDomainPlugin.pluginId,
    buildPage: _buildEntitiesPage,
  ),
  EditorHomeRoute(
    id: prefabCreatorRouteId,
    label: 'Prefab Creator',
    pluginId: PrefabDomainPlugin.pluginId,
    buildPage: _buildPrefabCreatorPage,
  ),
  EditorHomeRoute(
    id: chunkCreatorRouteId,
    label: 'Chunk Creator',
    pluginId: ChunkDomainPlugin.pluginId,
    buildPage: _buildChunkCreatorPage,
  ),
  EditorHomeRoute(
    id: levelCreatorRouteId,
    label: 'Level Creator',
    pluginId: LevelDomainPlugin.pluginId,
    buildPage: _buildLevelCreatorPage,
  ),
  EditorHomeRoute(
    id: parallaxEditorRouteId,
    label: 'Parallax',
    pluginId: ParallaxDomainPlugin.pluginId,
    buildPage: _buildParallaxEditorPage,
  ),
  EditorHomeRoute(
    id: terrainMaterialsRouteId,
    label: 'Terrain Materials',
    pluginId: TerrainMaterialDomainPlugin.pluginId,
    buildPage: _buildTerrainMaterialsPage,
  ),
];

Widget _buildEntitiesPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return EntitiesEditorPage(key: key, controller: controller);
}

Widget _buildPrefabCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return PrefabCreatorPage(
    key: key,
    controller: controller,
    initialPrefabKey: navigation.initialPrefabKey,
  );
}

Widget _buildChunkCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return ChunkCreatorPage(
    key: key,
    controller: controller,
    onOpenOwningPrefab: navigation.onOpenOwningPrefab,
  );
}

Widget _buildLevelCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return LevelCreatorPage(key: key, controller: controller);
}

Widget _buildParallaxEditorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return ParallaxEditorPage(key: key, controller: controller);
}

Widget _buildTerrainMaterialsPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return TerrainMaterialsPage(key: key, controller: controller);
}
