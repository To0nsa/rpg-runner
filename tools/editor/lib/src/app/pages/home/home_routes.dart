import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_plugin.dart';
import '../../../entities/entity_domain_plugin.dart';
import '../../../levels/level_domain_plugin.dart';
import '../../../parallax/parallax_domain_models.dart';
import '../../../parallax/parallax_domain_plugin.dart';
import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../../../terrain_materials/terrain_material_domain_plugin.dart';
import '../chunkCreator/chunk_creator_page.dart';
import '../chunkCreator/chunk_creator_location.dart';
import '../entities/entities_editor_page.dart';
import '../levelCreator/level_creator_page.dart';
import '../levelCreator/level_creator_navigation.dart';
import '../parallaxEditor/parallax_editor_page.dart';
import '../prefabCreator/prefab_creator_page.dart';
import '../prefabCreator/prefab_creator_navigation.dart';
import '../terrainMaterials/terrain_materials_page.dart';
import '../shared/editor_page_navigation_state.dart';

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
/// plugin-session state. The initial location is consumed by the matching route
/// only after its document has been loaded and its session selection restored.
@immutable
class EditorHomeRouteNavigation {
  const EditorHomeRouteNavigation({
    this.initialLocation,
    this.onOpenChunkForLevel,
    this.onShellStateChanged,
    this.onRepairDependency,
    this.onOpenPrefabTarget,
    this.onOpenParallaxForLevel,
  });

  final EditorPageLocation? initialLocation;
  final Future<bool> Function(LevelCreatorChunkTarget)? onOpenChunkForLevel;

  /// Requests a shell-control rebuild after page-owned lock state changes.
  final VoidCallback? onShellStateChanged;
  final Future<bool> Function(String pluginId)? onRepairDependency;

  /// Requests shell-owned navigation to an exact Prefab Creator target.
  final ValueChanged<PrefabCreatorTarget>? onOpenPrefabTarget;

  /// Requests a guarded transition to one freshly resolved Level/theme pair.
  final ValueChanged<ParallaxLevelTarget>? onOpenParallaxForLevel;
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
  return EntitiesEditorPage(
    initialLocation: navigation.initialLocation as EntitiesEditorLocation?,
    key: key,
    controller: controller,
    onShellStateChanged: navigation.onShellStateChanged,
  );
}

Widget _buildPrefabCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return PrefabCreatorPage(
    key: key,
    controller: controller,
    initialLocation: navigation.initialLocation as PrefabCreatorLocation?,
    onShellStateChanged: navigation.onShellStateChanged,
  );
}

Widget _buildChunkCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return ChunkCreatorPage(
    initialLocation: navigation.initialLocation as ChunkCreatorLocation?,
    key: key,
    controller: controller,
    onShellStateChanged: navigation.onShellStateChanged,
    onOpenPrefabTarget: navigation.onOpenPrefabTarget,
  );
}

Widget _buildLevelCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return LevelCreatorPage(
    key: key,
    controller: controller,
    onShellStateChanged: navigation.onShellStateChanged,
    onOpenInParallax: navigation.onOpenParallaxForLevel,
    onOpenChunk: navigation.onOpenChunkForLevel,
    initialReturnContext:
        navigation.initialLocation as LevelCreatorReturnContext?,
    onRepairDependency: navigation.onRepairDependency,
  );
}

Widget _buildParallaxEditorPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return ParallaxEditorPage(
    initialLocation: navigation.initialLocation as ParallaxEditorLocation?,
    key: key,
    controller: controller,
    onShellStateChanged: navigation.onShellStateChanged,
  );
}

Widget _buildTerrainMaterialsPage({
  required GlobalKey key,
  required EditorSessionController controller,
  required EditorHomeRouteNavigation navigation,
}) {
  return TerrainMaterialsPage(
    key: key,
    controller: controller,
    initialLocation: navigation.initialLocation as TerrainMaterialsLocation?,
  );
}
