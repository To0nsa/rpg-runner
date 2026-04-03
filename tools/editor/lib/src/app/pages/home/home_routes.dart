import '../../../chunks/chunk_domain_plugin.dart';
import '../../../entities/entity_domain_plugin.dart';
import '../../../prefabs/prefab_domain_plugin.dart';

class EditorHomeRoute {
  const EditorHomeRoute({required this.id, required this.label, this.pluginId});

  final String id;
  final String label;
  final String? pluginId;
}

const String entitiesRouteId = 'entities';
const String prefabCreatorRouteId = 'prefab_creator';
const String chunkCreatorRouteId = 'chunk_creator';

const List<EditorHomeRoute> homeRoutes = <EditorHomeRoute>[
  EditorHomeRoute(
    id: entitiesRouteId,
    label: 'Entities',
    pluginId: EntityDomainPlugin.pluginId,
  ),
  EditorHomeRoute(
    id: prefabCreatorRouteId,
    label: 'Prefab Creator',
    pluginId: PrefabDomainPlugin.pluginId,
  ),
  EditorHomeRoute(
    id: chunkCreatorRouteId,
    label: 'Chunk Creator',
    pluginId: ChunkDomainPlugin.pluginId,
  ),
];

EditorHomeRoute? findHomeRouteById(String routeId) {
  for (final route in homeRoutes) {
    if (route.id == routeId) {
      return route;
    }
  }
  return null;
}
