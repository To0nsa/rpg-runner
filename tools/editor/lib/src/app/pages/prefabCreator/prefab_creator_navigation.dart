import 'package:flutter/widgets.dart';

import '../../../prefabs/models/models.dart';
import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../shared/editor_page_navigation_state.dart';
import 'v3/prefab_workspace_view_selector.dart';

/// Remembers every Prefab Creator workspace without retaining authored data.
class PrefabCreatorLocation extends EditorPageLocation {
  const PrefabCreatorLocation({
    this.prefabKey,
    this.view = PrefabWorkspaceView.atlasSlices,
    this.zoom = 4,
    this.pan = Offset.zero,
    this.atlas,
    this.module,
    this.collisionSelection,
    this.collisionTool = TerrainPolygonTool.select,
  });

  final String? prefabKey;
  final PrefabWorkspaceView view;
  final double zoom;
  final Offset pan;
  final PrefabAtlasLocation? atlas;
  final PrefabModuleLocation? module;
  final TerrainPolygonSelection? collisionSelection;
  final TerrainPolygonTool collisionTool;

  /// Explicit source links override the remembered workspace and owner.
  factory PrefabCreatorLocation.forTarget(PrefabCreatorTarget target) =>
      PrefabCreatorLocation(
        prefabKey: target.prefabKey,
        view: switch (target.destination) {
          PrefabCreatorDestination.prefab => PrefabWorkspaceView.prefabs,
          PrefabCreatorDestination.collision => PrefabWorkspaceView.collision,
          PrefabCreatorDestination.atlas => PrefabWorkspaceView.atlasSlices,
        },
      );
}

/// Catalog identities only; an unfinished atlas rectangle is a draft.
class PrefabAtlasLocation {
  const PrefabAtlasLocation({
    required this.kind,
    this.sourcePath,
    this.prefabSliceId,
    this.tileSliceId,
  });
  final AtlasSliceKind kind;
  final String? sourcePath;
  final String? prefabSliceId;
  final String? tileSliceId;
}

/// Stable module and painting-tile identities, revalidated on entry.
class PrefabModuleLocation {
  const PrefabModuleLocation({this.moduleId, this.tileSliceId});
  final String? moduleId;
  final String? tileSliceId;
}

/// Prefab Creator surface requested by another authoring workspace.
enum PrefabCreatorDestination { prefab, atlas, collision }

/// Stable cross-route target for opening one prefab in a specific workflow.
@immutable
class PrefabCreatorTarget {
  const PrefabCreatorTarget({
    required this.prefabKey,
    required this.destination,
  });

  final String prefabKey;
  final PrefabCreatorDestination destination;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrefabCreatorTarget &&
          prefabKey == other.prefabKey &&
          destination == other.destination;

  @override
  int get hashCode => Object.hash(prefabKey, destination);
}
