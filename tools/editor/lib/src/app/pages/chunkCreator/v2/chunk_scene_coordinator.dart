import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';

/// Explicit owner of primary input in the shared Chunk scene.
enum ChunkSceneDomain { terrain, prefabs, markers, compiledEdgeInspection }

/// Typed route-local selection for the shared Chunk scene.
sealed class ChunkSceneSelection {
  const ChunkSceneSelection();
}

@immutable
final class ChunkTerrainSceneSelection extends ChunkSceneSelection {
  const ChunkTerrainSceneSelection(this.selection);

  final TerrainPolygonSelection selection;
}

@immutable
final class ChunkPrefabSceneSelection extends ChunkSceneSelection {
  const ChunkPrefabSceneSelection(this.selection);

  final ChunkPlacedPrefabSelection selection;
}

@immutable
final class ChunkMarkerSceneSelection extends ChunkSceneSelection {
  const ChunkMarkerSceneSelection(this.selection);

  final ChunkPlacedMarkerSelection selection;
}

@immutable
final class ChunkCompiledEdgeSceneSelection extends ChunkSceneSelection {
  const ChunkCompiledEdgeSceneSelection(this.edgeId);

  final TerrainEdgeId edgeId;
}

/// Focused route coordinator for domain and selection state only.
///
/// It never owns a document, validation, history, or persistence path.
final class ChunkSceneCoordinator {
  ChunkSceneDomain _domain = ChunkSceneDomain.terrain;
  ChunkSceneDomain _sourceDomainBeforeInspection = ChunkSceneDomain.terrain;
  ChunkSceneSelection? _selection;

  ChunkSceneDomain get domain => _domain;
  ChunkSceneDomain get sourceDomain =>
      _domain == ChunkSceneDomain.compiledEdgeInspection
      ? _sourceDomainBeforeInspection
      : _domain;
  ChunkSceneSelection? get selection => _selection;

  String? get selectedPrefabKey => switch (_selection) {
    ChunkPrefabSceneSelection(:final selection) => selection.selectionKey,
    _ => null,
  };

  String? get selectedMarkerKey => switch (_selection) {
    ChunkMarkerSceneSelection(:final selection) => selection.selectionKey,
    _ => null,
  };

  TerrainEdgeId? get selectedCompiledEdgeId => switch (_selection) {
    ChunkCompiledEdgeSceneSelection(:final edgeId) => edgeId,
    _ => null,
  };

  void bindOwner() {
    _domain = ChunkSceneDomain.terrain;
    _sourceDomainBeforeInspection = ChunkSceneDomain.terrain;
    _selection = null;
  }

  void setSourceDomain(ChunkSceneDomain domain) {
    assert(domain != ChunkSceneDomain.compiledEdgeInspection);
    _domain = domain;
    _sourceDomainBeforeInspection = domain;
    _selection = null;
  }

  void setCompiledEdgeInspection(bool enabled) {
    if (enabled) {
      if (_domain != ChunkSceneDomain.compiledEdgeInspection) {
        _sourceDomainBeforeInspection = _domain;
      }
      _domain = ChunkSceneDomain.compiledEdgeInspection;
    } else {
      _domain = _sourceDomainBeforeInspection;
    }
    _selection = null;
  }

  void selectTerrain(TerrainPolygonSelection? selection) {
    if (_domain != ChunkSceneDomain.terrain) return;
    _selection = selection == null
        ? null
        : ChunkTerrainSceneSelection(selection);
  }

  void selectPrefab(ChunkPlacedPrefabSelection? selection) {
    _domain = ChunkSceneDomain.prefabs;
    _sourceDomainBeforeInspection = _domain;
    _selection = selection == null
        ? null
        : ChunkPrefabSceneSelection(selection);
  }

  void selectMarker(ChunkPlacedMarkerSelection? selection) {
    _domain = ChunkSceneDomain.markers;
    _sourceDomainBeforeInspection = _domain;
    _selection = selection == null
        ? null
        : ChunkMarkerSceneSelection(selection);
  }

  void selectCompiledEdge(TerrainEdgeId? edgeId) {
    if (_domain != ChunkSceneDomain.compiledEdgeInspection) return;
    _selection = edgeId == null
        ? null
        : ChunkCompiledEdgeSceneSelection(edgeId);
  }

  void clearSelection() => _selection = null;

  void reconcileComposition(ChunkV2FileData chunk) {
    switch (_selection) {
      case ChunkPrefabSceneSelection(:final selection):
        final resolved = resolveChunkPrefabSelection(
          chunk.prefabs,
          selection.selectionKey,
        );
        _selection = resolved == null
            ? null
            : ChunkPrefabSceneSelection(resolved);
      case ChunkMarkerSceneSelection(:final selection):
        final resolved = resolveChunkMarkerSelection(
          chunk.markers,
          selection.selectionKey,
        );
        _selection = resolved == null
            ? null
            : ChunkMarkerSceneSelection(resolved);
      case ChunkTerrainSceneSelection() ||
          ChunkCompiledEdgeSceneSelection() ||
          null:
        break;
    }
  }
}

/// Selects the last-painted authored marker anchor within [radiusWorld].
///
/// Marker projection order is the canonical source order. Iterating it in
/// reverse makes equal-location ties deterministic without consulting resolved
/// Core placement evidence.
ChunkPlacedMarkerSelection? hitTestChunkMarkerSelection({
  required Iterable<PlacedMarkerDef> markers,
  required double worldX,
  required double worldY,
  required double radiusWorld,
}) {
  if (!worldX.isFinite ||
      !worldY.isFinite ||
      !radiusWorld.isFinite ||
      radiusWorld < 0) {
    return null;
  }
  final radiusSquared = radiusWorld * radiusWorld;
  for (final selection in buildChunkPlacedMarkerSelections(markers).reversed) {
    final dx = selection.marker.x - worldX;
    final dy = selection.marker.y - worldY;
    if (dx * dx + dy * dy <= radiusSquared) return selection;
  }
  return null;
}
