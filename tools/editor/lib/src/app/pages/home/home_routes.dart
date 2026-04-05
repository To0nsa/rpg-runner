import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_plugin.dart';
import '../../../entities/entity_domain_plugin.dart';
import '../../../prefabs/prefab_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../chunkCreator/chunk_creator_page.dart';
import '../entities/entities_editor_page.dart';
import '../prefabCreator/prefab_creator_page.dart';

class EditorHomeRoute {
  const EditorHomeRoute({
    required this.id,
    required this.label,
    required this.pluginId,
    required this.buildPage,
  });

  final String id;
  final String label;
  final String pluginId;
  final Widget Function({
    required GlobalKey key,
    required EditorSessionController controller,
  })
  buildPage;
}

const String entitiesRouteId = 'entities';
const String prefabCreatorRouteId = 'prefab_creator';
const String chunkCreatorRouteId = 'chunk_creator';

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
