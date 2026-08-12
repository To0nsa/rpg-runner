import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';

import 'chunk_domain_models.dart';
import 'chunk_v2_actor_terrain_projection.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_marker_contract.dart';

/// Editor-facing outcome category for one authored enemy marker.
enum ChunkV2MarkerPlacementDisposition {
  guaranteedAccepted,
  conditionalAccepted,
  guaranteedRejected,
  conditionalRejected,
  disabled,
  deferredGuaranteed,
  deferredConditional,
  malformed,
}

/// One immutable marker diagnostic in original authored order.
///
/// [marker.y] remains editor positioning metadata. The placement request's Y
/// is derived from the selected support exactly as runtime does; no diagnostic
/// consumes RNG or relocates an authored marker.
@immutable
final class ChunkV2MarkerPlacementOutcome {
  ChunkV2MarkerPlacementOutcome({
    required this.sourceIndex,
    required this.selectionKey,
    required this.marker,
    required this.enemyId,
    required this.supportSelection,
    required this.intendedSurface,
    required this.profile,
    required this.result,
    required this.disposition,
    required this.code,
    required this.message,
    Iterable<String> malformedCodes = const <String>[],
  }) : malformedCodes = List<String>.unmodifiable(malformedCodes);

  final int sourceIndex;
  final String selectionKey;
  final PlacedMarkerDef marker;
  final EnemyId? enemyId;
  final TerrainSpawnSupportSelection? supportSelection;
  final TerrainNavigationSurface? intendedSurface;
  final TerrainEnemySpawnPlacementProfile? profile;
  final TerrainSpawnPlacementResult? result;
  final ChunkV2MarkerPlacementDisposition disposition;
  final String code;
  final String message;
  final List<String> malformedCodes;

  bool get accepted => result?.accepted ?? false;
  bool get deferred =>
      disposition == ChunkV2MarkerPlacementDisposition.deferredGuaranteed ||
      disposition == ChunkV2MarkerPlacementDisposition.deferredConditional;
}

/// Read-only terrain-placement evidence for a current chunk's authored markers.
@immutable
final class ChunkV2MarkerPlacementProjection {
  factory ChunkV2MarkerPlacementProjection.build({
    required ChunkV2FileData chunk,
    required ChunkV2ActorTerrainProjection actorTerrain,
    required double? levelGroundTopY,
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
    UnocoDemonTuning unocoTuning = const UnocoDemonTuning(),
  }) {
    final selectionKeys = _selectionKeysInSourceOrder(chunk.markers);
    final outcomes = <ChunkV2MarkerPlacementOutcome>[];
    final groundTopYTicks = _tryGroundTopYTicks(levelGroundTopY);
    final resolver = TerrainSpawnPlacementResolver(
      placementQuery: TerrainPlacementQuery(
        geometry: actorTerrain.bundle.geometry,
        terrainIndex: actorTerrain.bundle.edgeIndex,
        surfaceIndex: actorTerrain.bundle.surfaceIndex,
      ),
    );

    for (
      var sourceIndex = 0;
      sourceIndex < chunk.markers.length;
      sourceIndex++
    ) {
      final marker = chunk.markers[sourceIndex];
      final malformedCodes = chunkV2MarkerContractCodes(
        chunk: chunk,
        marker: marker,
        hasGroundContext: groundTopYTicks != null,
      );
      final enemyId = _parseEnemyId(marker.markerId);
      final supportSelection = _parseSupportSelection(marker.placement);
      final selectionKey = selectionKeys[sourceIndex];
      if (malformedCodes.isNotEmpty ||
          enemyId == null ||
          supportSelection == null ||
          groundTopYTicks == null) {
        outcomes.add(
          ChunkV2MarkerPlacementOutcome(
            sourceIndex: sourceIndex,
            selectionKey: selectionKey,
            marker: marker,
            enemyId: enemyId,
            supportSelection: supportSelection,
            intendedSurface: null,
            profile: null,
            result: null,
            disposition: ChunkV2MarkerPlacementDisposition.malformed,
            code: malformedCodes.isEmpty
                ? 'marker_contract_invalid'
                : malformedCodes.first,
            message: _malformedMessage(malformedCodes),
            malformedCodes: malformedCodes,
          ),
        );
        continue;
      }

      if (marker.chancePercent == 0) {
        outcomes.add(
          ChunkV2MarkerPlacementOutcome(
            sourceIndex: sourceIndex,
            selectionKey: selectionKey,
            marker: marker,
            enemyId: enemyId,
            supportSelection: supportSelection,
            intendedSurface: null,
            profile: null,
            result: null,
            disposition: ChunkV2MarkerPlacementDisposition.disabled,
            code: 'marker_disabled',
            message: '0% chance: runtime never attempts this marker.',
          ),
        );
        continue;
      }

      if (enemyId == EnemyId.hashash) {
        final guaranteed = marker.chancePercent == 100;
        outcomes.add(
          ChunkV2MarkerPlacementOutcome(
            sourceIndex: sourceIndex,
            selectionKey: selectionKey,
            marker: marker,
            enemyId: enemyId,
            supportSelection: supportSelection,
            intendedSurface: null,
            profile: null,
            result: null,
            disposition: guaranteed
                ? ChunkV2MarkerPlacementDisposition.deferredGuaranteed
                : ChunkV2MarkerPlacementDisposition.deferredConditional,
            code: 'marker_hashash_deferred',
            message:
                '${marker.chancePercent}% chance: the marker contributes one '
                'deferred Hashash spawn; runtime chooses the visible '
                'camera-right chunk edge later.',
          ),
        );
        continue;
      }

      final markerXTicks = marker.x * terrainPhysicsTicksPerWorldUnit;
      final intendedSurface = _selectIntendedSurface(
        surfaces: actorTerrain.surfaceSet.surfaces,
        selection: supportSelection,
        markerXTicks: markerXTicks,
        groundTopYTicks: groundTopYTicks,
      );
      final requestedSupportYTicks = intendedSurface == null
          ? groundTopYTicks
          : intendedSurface.yAtXTicks(markerXTicks);
      final profile = TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: enemyCatalog,
        enemyId: enemyId,
        facing: Facing.left,
      );
      final desiredBodyYTicks = enemyId == EnemyId.unocoDemon
          ? requestedSupportYTicks -
                physicsCoordinateToTicks(
                  unocoTuning.unocoDemonHoverOffsetY,
                  name: 'unocoDemonHoverOffsetY',
                )
          : requestedSupportYTicks -
                profile.capsule.radiusTicks -
                profile.capsule.verticalHalfSegmentTicks -
                profile.capsule.offsetYTicks;
      final result = resolver.resolve(
        TerrainSpawnPlacementRequest(
          profile: profile,
          desiredBodyCenter: TerrainPoint(markerXTicks, desiredBodyYTicks),
          supportSelection: supportSelection,
          requestedSupportYTicks: requestedSupportYTicks,
          intendedSupportEdgeId: intendedSurface?.id,
          intendedSourceAvailable: intendedSurface != null,
          allowSameSupportClamp: enemyId != EnemyId.unocoDemon,
        ),
      );
      final guaranteed = marker.chancePercent == 100;
      outcomes.add(
        ChunkV2MarkerPlacementOutcome(
          sourceIndex: sourceIndex,
          selectionKey: selectionKey,
          marker: marker,
          enemyId: enemyId,
          supportSelection: supportSelection,
          intendedSurface: intendedSurface,
          profile: profile,
          result: result,
          disposition: result.accepted
              ? (guaranteed
                    ? ChunkV2MarkerPlacementDisposition.guaranteedAccepted
                    : ChunkV2MarkerPlacementDisposition.conditionalAccepted)
              : (guaranteed
                    ? ChunkV2MarkerPlacementDisposition.guaranteedRejected
                    : ChunkV2MarkerPlacementDisposition.conditionalRejected),
          code: result.accepted
              ? (guaranteed
                    ? 'marker_placement_guaranteed'
                    : 'marker_placement_conditional')
              : 'marker_placement_${result.validity.name}',
          message: result.accepted
              ? '${marker.chancePercent}% chance: Core accepts the exact '
                    '${marker.placement} placement.'
              : '${marker.chancePercent}% chance: Core rejects the exact '
                    '${marker.placement} placement '
                    '(${result.validity.name}).',
        ),
      );
    }

    return ChunkV2MarkerPlacementProjection._(outcomes);
  }

  ChunkV2MarkerPlacementProjection._(
    Iterable<ChunkV2MarkerPlacementOutcome> outcomes,
  ) : outcomes = List<ChunkV2MarkerPlacementOutcome>.unmodifiable(outcomes),
      _bySelectionKey = Map<String, ChunkV2MarkerPlacementOutcome>.unmodifiable(
        <String, ChunkV2MarkerPlacementOutcome>{
          for (final outcome in outcomes) outcome.selectionKey: outcome,
        },
      );

  final List<ChunkV2MarkerPlacementOutcome> outcomes;
  final Map<String, ChunkV2MarkerPlacementOutcome> _bySelectionKey;

  UnmodifiableMapView<String, ChunkV2MarkerPlacementOutcome>
  get bySelectionKey => UnmodifiableMapView(_bySelectionKey);

  ChunkV2MarkerPlacementOutcome? outcomeFor(String? selectionKey) =>
      selectionKey == null ? null : _bySelectionKey[selectionKey];
}

String _malformedMessage(List<String> codes) =>
    'Marker contract is malformed: ${codes.join(', ')}.';

EnemyId? _parseEnemyId(String value) {
  for (final enemyId in EnemyId.values) {
    if (enemyId.name == value) return enemyId;
  }
  return null;
}

TerrainSpawnSupportSelection? _parseSupportSelection(String value) =>
    switch (value) {
      markerPlacementGround => TerrainSpawnSupportSelection.ground,
      markerPlacementHighestSurfaceAtX =>
        TerrainSpawnSupportSelection.highestSurfaceAtX,
      markerPlacementObstacleTop => TerrainSpawnSupportSelection.obstacleTop,
      _ => null,
    };

int? _tryGroundTopYTicks(double? value) {
  if (!isChunkV2MarkerGroundContextValid(value)) return null;
  return physicsCoordinateToTicks(value!, name: 'levelGroundTopY');
}

TerrainNavigationSurface? _selectIntendedSurface({
  required Iterable<TerrainNavigationSurface> surfaces,
  required TerrainSpawnSupportSelection selection,
  required int markerXTicks,
  required int groundTopYTicks,
}) {
  TerrainNavigationSurface? selected;
  for (final surface in surfaces) {
    if (markerXTicks < surface.xMinTicks || markerXTicks > surface.xMaxTicks) {
      continue;
    }
    final supportY = surface.yAtXTicks(markerXTicks);
    final eligibleSource = switch (selection) {
      TerrainSpawnSupportSelection.ground =>
        surface.id.placementKey == null &&
            surface.collisionMode == TerrainCollisionMode.solid &&
            supportY == groundTopYTicks,
      TerrainSpawnSupportSelection.highestSurfaceAtX => true,
      TerrainSpawnSupportSelection.obstacleTop =>
        surface.id.placementKey != null &&
            surface.collisionMode == TerrainCollisionMode.solid,
      TerrainSpawnSupportSelection.none ||
      TerrainSpawnSupportSelection.deferredEdge => false,
    };
    if (!eligibleSource) continue;
    if (selected == null) {
      selected = surface;
      continue;
    }
    final selectedY = selected.yAtXTicks(markerXTicks);
    if ((selection != TerrainSpawnSupportSelection.ground &&
            supportY < selectedY) ||
        (supportY == selectedY && surface.id.compareTo(selected.id) < 0)) {
      selected = surface;
    }
  }
  return selected;
}

List<String> _selectionKeysInSourceOrder(List<PlacedMarkerDef> markers) {
  final selections = buildChunkPlacedMarkerSelections(markers);
  final used = <int>{};
  return <String>[
    for (final marker in markers)
      _takeSelectionKey(marker: marker, selections: selections, used: used),
  ];
}

String _takeSelectionKey({
  required PlacedMarkerDef marker,
  required List<ChunkPlacedMarkerSelection> selections,
  required Set<int> used,
}) {
  for (var index = 0; index < selections.length; index++) {
    if (used.contains(index)) continue;
    final candidate = selections[index].marker;
    if (!_sameMarker(candidate, marker)) continue;
    used.add(index);
    return selections[index].selectionKey;
  }
  throw StateError('Every source marker must retain one stable selection key.');
}

bool _sameMarker(PlacedMarkerDef left, PlacedMarkerDef right) =>
    left.markerId == right.markerId &&
    left.x == right.x &&
    left.y == right.y &&
    left.chancePercent == right.chancePercent &&
    left.salt == right.salt &&
    left.placement == right.placement;
