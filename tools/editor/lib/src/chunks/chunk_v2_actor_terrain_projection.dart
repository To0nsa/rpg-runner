import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:runner_core/collision/terrain/terrain_edge.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';

import 'chunk_v2_collision_expansion.dart';

/// Actor policies exposed by the staged Chunk terrain diagnostic overlay.
enum ChunkV2TerrainActor { eloise, grojib, hashash, unoco, derf }

/// One grounded actor's exact Core surface-eligibility and graph publication.
///
/// Éloïse intentionally has no graph: Core owns a player traversal profile,
/// but no player pathfinding profile. Grojib and Hashash retain the two exact
/// Phase 3 graph views built by [TerrainRuntimeBundle].
@immutable
final class ChunkV2GroundedTerrainView {
  ChunkV2GroundedTerrainView({
    required this.actor,
    required this.traversalProfile,
    required TerrainSurfaceSet surfaceSet,
    required Iterable<bool> eligibility,
    required this.graph,
  }) : _surfaceSet = surfaceSet,
       eligibility = List<bool>.unmodifiable(eligibility) {
    if (this.eligibility.length != surfaceSet.surfaces.length) {
      throw ArgumentError(
        'Grounded actor eligibility must match the shared surface set.',
      );
    }
    if (graph != null && !identical(graph!.surfaceSet, surfaceSet)) {
      throw ArgumentError(
        'Grounded actor graph must use the shared surface-set identity.',
      );
    }
  }

  final ChunkV2TerrainActor actor;
  final TerrainTraversalProfile traversalProfile;
  final TerrainSurfaceSet _surfaceSet;
  final List<bool> eligibility;
  final TerrainSurfaceGraph? graph;

  Iterable<TerrainNavigationSurface> get eligibleSurfaces sync* {
    for (var index = 0; index < eligibility.length; index += 1) {
      if (eligibility[index]) yield _surfaceSet.surfaces[index];
    }
  }

  bool isEligible(TerrainEdgeId edgeId) {
    final index = _surfaceSet.indexOfId(edgeId);
    return index != null && eligibility[index];
  }
}

/// Exact Core evidence for one upward surface considered as a Derf perch.
@immutable
final class ChunkV2DerfPerchEvidence {
  const ChunkV2DerfPerchEvidence({
    required this.surface,
    required this.slopeAndModeEligible,
    required this.supportSpanEligible,
  });

  final TerrainNavigationSurface surface;
  final bool slopeAndModeEligible;
  final bool supportSpanEligible;

  bool get perchEligible => slopeAndModeEligible && supportSpanEligible;
}

/// Immutable actor-facing diagnostics derived from one accepted expansion.
///
/// This projection delegates surface extraction and enemy graph construction
/// to Core. It consumes no RNG, mutates no source, and deliberately does not
/// construct a player or flying-enemy graph that runtime does not own.
@immutable
final class ChunkV2ActorTerrainProjection {
  factory ChunkV2ActorTerrainProjection.build(
    ChunkV2CollisionExpansion expansion, {
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
  }) {
    final bundle = TerrainRuntimeBundle.build(
      geometry: expansion.geometry,
      groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(
        enemyCatalog: enemyCatalog,
      ),
    );
    final surfaceSet = bundle.surfaceSet;
    final eloiseProfile = createEloiseTerrainTraversalProfile(
      enabled: true,
      isKinematic: false,
      useGravity: true,
      gravityScale: 1,
      collideCeilings: true,
      collideLeftWalls: true,
      collideRightWalls: true,
    );
    final grojibProfile = enemyCatalog.terrainContactProfile(EnemyId.grojib);
    final hashashProfile = enemyCatalog.terrainContactProfile(EnemyId.hashash);
    final derfProfile = enemyCatalog.terrainContactProfile(EnemyId.derf);
    final grojibGraph = bundle.grojibGraph;
    final hashashGraph = bundle.hashashGraph;

    final groundedViews = <ChunkV2TerrainActor, ChunkV2GroundedTerrainView>{
      ChunkV2TerrainActor.eloise: ChunkV2GroundedTerrainView(
        actor: ChunkV2TerrainActor.eloise,
        traversalProfile: eloiseProfile,
        surfaceSet: surfaceSet,
        eligibility: <bool>[
          for (final surface in surfaceSet.surfaces)
            surface.isEligibleFor(eloiseProfile),
        ],
        graph: null,
      ),
      ChunkV2TerrainActor.grojib: ChunkV2GroundedTerrainView(
        actor: ChunkV2TerrainActor.grojib,
        traversalProfile: grojibProfile.traversal,
        surfaceSet: surfaceSet,
        eligibility: grojibGraph.eligibility,
        graph: grojibGraph,
      ),
      ChunkV2TerrainActor.hashash: ChunkV2GroundedTerrainView(
        actor: ChunkV2TerrainActor.hashash,
        traversalProfile: hashashProfile.traversal,
        surfaceSet: surfaceSet,
        eligibility: hashashGraph.eligibility,
        graph: hashashGraph,
      ),
    };
    final unocoSolidBlockerIds = <TerrainEdgeId>{
      for (final edge in expansion.geometry.edges)
        if (edge.collisionMode == TerrainCollisionMode.solid) edge.id,
    };
    final unocoLocalHoverCandidateIds = <TerrainEdgeId>{
      for (final surface in surfaceSet.surfaces)
        if (surface.collisionMode == TerrainCollisionMode.solid) surface.id,
    };
    final derfPerches = <TerrainEdgeId, ChunkV2DerfPerchEvidence>{
      for (final surface in surfaceSet.surfaces)
        surface.id: ChunkV2DerfPerchEvidence(
          surface: surface,
          slopeAndModeEligible: surface.isEligibleFor(derfProfile.traversal),
          supportSpanEligible: surface.dxTicks >= derfMinimumSupportSpanTicks,
        ),
    };

    return ChunkV2ActorTerrainProjection._(
      expansion: expansion,
      bundle: bundle,
      groundedViews:
          Map<ChunkV2TerrainActor, ChunkV2GroundedTerrainView>.unmodifiable(
            groundedViews,
          ),
      unocoSolidBlockerIds: Set<TerrainEdgeId>.unmodifiable(
        unocoSolidBlockerIds,
      ),
      unocoLocalHoverCandidateIds: Set<TerrainEdgeId>.unmodifiable(
        unocoLocalHoverCandidateIds,
      ),
      derfPerches: Map<TerrainEdgeId, ChunkV2DerfPerchEvidence>.unmodifiable(
        derfPerches,
      ),
    );
  }

  const ChunkV2ActorTerrainProjection._({
    required this.expansion,
    required this.bundle,
    required Map<ChunkV2TerrainActor, ChunkV2GroundedTerrainView> groundedViews,
    required Set<TerrainEdgeId> unocoSolidBlockerIds,
    required Set<TerrainEdgeId> unocoLocalHoverCandidateIds,
    required Map<TerrainEdgeId, ChunkV2DerfPerchEvidence> derfPerches,
  }) : _groundedViews = groundedViews,
       _unocoSolidBlockerIds = unocoSolidBlockerIds,
       _unocoLocalHoverCandidateIds = unocoLocalHoverCandidateIds,
       _derfPerches = derfPerches;

  final ChunkV2CollisionExpansion expansion;
  final TerrainRuntimeBundle bundle;
  final Map<ChunkV2TerrainActor, ChunkV2GroundedTerrainView> _groundedViews;
  final Set<TerrainEdgeId> _unocoSolidBlockerIds;
  final Set<TerrainEdgeId> _unocoLocalHoverCandidateIds;
  final Map<TerrainEdgeId, ChunkV2DerfPerchEvidence> _derfPerches;

  TerrainSurfaceSet get surfaceSet => bundle.surfaceSet;

  UnmodifiableSetView<TerrainEdgeId> get unocoSolidBlockerIds =>
      UnmodifiableSetView<TerrainEdgeId>(_unocoSolidBlockerIds);

  UnmodifiableSetView<TerrainEdgeId> get unocoLocalHoverCandidateIds =>
      UnmodifiableSetView<TerrainEdgeId>(_unocoLocalHoverCandidateIds);

  ChunkV2GroundedTerrainView? groundedView(ChunkV2TerrainActor actor) =>
      _groundedViews[actor];

  bool isUnocoSolidBlocker(TerrainEdgeId edgeId) =>
      _unocoSolidBlockerIds.contains(edgeId);

  bool isUnocoLocalHoverCandidate(TerrainEdgeId edgeId) =>
      _unocoLocalHoverCandidateIds.contains(edgeId);

  ChunkV2DerfPerchEvidence? derfPerchEvidence(TerrainEdgeId edgeId) =>
      _derfPerches[edgeId];

  Iterable<ChunkV2DerfPerchEvidence> get derfPerches => _derfPerches.values;

  TerrainEdge? edgeById(TerrainEdgeId edgeId) =>
      expansion.geometry.edgeById[edgeId];
}
