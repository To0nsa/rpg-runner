import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';

import '../../../../chunks/chunk_domain_models.dart';
import '../../../../chunks/chunk_v2_composition_operation.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_polygon_interaction.dart';

/// Explicit authoring tab and primary-input owner in the shared Chunk scene.
///
/// [layers] is intentionally passive because tile layers are metadata-only in
/// the current editor. [compiledEdgeInspection] remains an internal scene mode
/// rather than a user-facing workspace tab.
enum ChunkSceneDomain {
  terrain,
  prefabs,
  markers,
  layers,
  compiledEdgeInspection,
}

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
  final Map<ChunkSceneDomain, ChunkSceneSelection?> _selections =
      <ChunkSceneDomain, ChunkSceneSelection?>{};

  ChunkSceneDomain get domain => _domain;
  ChunkSceneDomain get sourceDomain =>
      _domain == ChunkSceneDomain.compiledEdgeInspection
      ? _sourceDomainBeforeInspection
      : _domain;
  ChunkSceneSelection? get selection => _selections[_domain];

  String? get selectedPrefabKey =>
      switch (sourceDomain == ChunkSceneDomain.prefabs
      ? _selections[ChunkSceneDomain.prefabs]
      : null) {
        ChunkPrefabSceneSelection(:final selection) => selection.selectionKey,
        _ => null,
      };

  String? get selectedMarkerKey =>
      switch (sourceDomain == ChunkSceneDomain.markers
      ? _selections[ChunkSceneDomain.markers]
      : null) {
        ChunkMarkerSceneSelection(:final selection) => selection.selectionKey,
        _ => null,
      };

  TerrainEdgeId? get selectedCompiledEdgeId =>
      switch (_selections[ChunkSceneDomain.compiledEdgeInspection]) {
        ChunkCompiledEdgeSceneSelection(:final edgeId) => edgeId,
        _ => null,
      };

  void bindOwner() {
    _domain = ChunkSceneDomain.terrain;
    _sourceDomainBeforeInspection = ChunkSceneDomain.terrain;
    _selections.clear();
  }

  void setSourceDomain(ChunkSceneDomain domain) {
    assert(domain != ChunkSceneDomain.compiledEdgeInspection);
    _domain = domain;
    _sourceDomainBeforeInspection = domain;
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
    _selections.remove(ChunkSceneDomain.compiledEdgeInspection);
  }

  void selectTerrain(TerrainPolygonSelection? selection) {
    if (_domain != ChunkSceneDomain.terrain) return;
    _setSelection(
      ChunkSceneDomain.terrain,
      selection == null ? null : ChunkTerrainSceneSelection(selection),
    );
  }

  void selectPrefab(ChunkPlacedPrefabSelection? selection) {
    _domain = ChunkSceneDomain.prefabs;
    _sourceDomainBeforeInspection = _domain;
    _setSelection(
      ChunkSceneDomain.prefabs,
      selection == null ? null : ChunkPrefabSceneSelection(selection),
    );
  }

  void selectMarker(ChunkPlacedMarkerSelection? selection) {
    _domain = ChunkSceneDomain.markers;
    _sourceDomainBeforeInspection = _domain;
    _setSelection(
      ChunkSceneDomain.markers,
      selection == null ? null : ChunkMarkerSceneSelection(selection),
    );
  }

  void selectCompiledEdge(TerrainEdgeId? edgeId) {
    if (_domain != ChunkSceneDomain.compiledEdgeInspection) return;
    _setSelection(
      ChunkSceneDomain.compiledEdgeInspection,
      edgeId == null ? null : ChunkCompiledEdgeSceneSelection(edgeId),
    );
  }

  void clearSelection() => _selections.remove(_domain);

  void reconcileComposition(ChunkV2FileData chunk) {
    switch (_selections[ChunkSceneDomain.prefabs]) {
      case ChunkPrefabSceneSelection(:final selection):
        final resolved = resolveChunkPrefabSelection(
          chunk.prefabs,
          selection.selectionKey,
        );
        _setSelection(
          ChunkSceneDomain.prefabs,
          resolved == null ? null : ChunkPrefabSceneSelection(resolved),
        );
      case ChunkTerrainSceneSelection() ||
          ChunkMarkerSceneSelection() ||
          ChunkCompiledEdgeSceneSelection() ||
          null:
        break;
    }
    switch (_selections[ChunkSceneDomain.markers]) {
      case ChunkMarkerSceneSelection(:final selection):
        final resolved = resolveChunkMarkerSelection(
          chunk.markers,
          selection.selectionKey,
        );
        _setSelection(
          ChunkSceneDomain.markers,
          resolved == null ? null : ChunkMarkerSceneSelection(resolved),
        );
      case ChunkTerrainSceneSelection() ||
          ChunkPrefabSceneSelection() ||
          ChunkCompiledEdgeSceneSelection() ||
          null:
        break;
    }
  }

  void _setSelection(ChunkSceneDomain domain, ChunkSceneSelection? selection) {
    if (selection == null) {
      _selections.remove(domain);
    } else {
      _selections[domain] = selection;
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
