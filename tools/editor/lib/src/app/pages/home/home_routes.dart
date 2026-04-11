import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_plugin.dart';
import '../../../entities/entity_domain_plugin.dart';
import '../../../parallax/parallax_domain_plugin.dart';
import '../../../prefabs/domain/prefab_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../chunkCreator/chunk_creator_page.dart';
import '../entities/entities_editor_page.dart';
import '../parallaxEditor/parallax_editor_page.dart';
import '../prefabCreator/prefab_creator_page.dart';

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
  })
  buildPage;
}

const String entitiesRouteId = 'entities';
const String prefabCreatorRouteId = 'prefab_creator';
const String chunkCreatorRouteId = 'chunk_creator';
const String parallaxEditorRouteId = 'parallax_editor';

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
    id: parallaxEditorRouteId,
    label: 'Parallax',
    pluginId: ParallaxDomainPlugin.pluginId,
    buildPage: _buildParallaxEditorPage,
  ),
];

Widget _buildEntitiesPage({
  required GlobalKey key,
  required EditorSessionController controller,
}) {
  return EntitiesEditorPage(key: key, controller: controller);
}

Widget _buildPrefabCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
}) {
  return PrefabCreatorPage(key: key, controller: controller);
}

Widget _buildChunkCreatorPage({
  required GlobalKey key,
  required EditorSessionController controller,
}) {
  return ChunkCreatorPage(key: key, controller: controller);
}

Widget _buildParallaxEditorPage({
  required GlobalKey key,
  required EditorSessionController controller,
}) {
  return ParallaxEditorPage(key: key, controller: controller);
}
