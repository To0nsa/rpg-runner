import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_graph_builder.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/navigation/utils/jump_template.dart';
import 'package:test/test.dart';

import '../fixtures/slopes_golden_fixture.dart';

void main() {
  group('shared profile graph views', () {
    test('retain identical nodes while eligibility and edges differ', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final grojib = fixture.builder.build(_profile(EnemyId.grojib));
      final hashash = fixture.builder.build(_profile(EnemyId.hashash));
      final publication = TerrainSurfaceGraphPublication(<TerrainSurfaceGraph>[
        hashash,
        grojib,
      ]);
      final exactFortyFive = fixture.surfaces.surfaces.singleWhere(
        (surface) => -surface.outwardNormal.yTicks == 724,
      );
      final exactSixty = fixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(56) &&
            surface.dyTicks.abs() == _ticks(97),
      );
      final fortyFiveIndex = fixture.surfaces.indexOfId(exactFortyFive.id)!;
      final sixtyIndex = fixture.surfaces.indexOfId(exactSixty.id)!;

      expect(identical(grojib.surfaceSet, hashash.surfaceSet), isTrue);
      expect(identical(publication.surfaceSet, fixture.surfaces), isTrue);
      expect(grojib.surfaces, same(hashash.surfaces));
      expect(
        grojib.surfaces.map((surface) => surface.id),
        orderedEquals(hashash.surfaces.map((surface) => surface.id)),
      );
      expect(grojib.eligibility[fortyFiveIndex], isTrue);
      expect(hashash.eligibility[fortyFiveIndex], isTrue);
      expect(grojib.eligibility[sixtyIndex], isFalse);
      expect(hashash.eligibility[sixtyIndex], isTrue);
      expect(grojib.edges.length, isNot(hashash.edges.length));
      expect(publication['grojib'], same(grojib));
      expect(publication['hashash'], same(hashash));
    });

    test('45, between-limit, and 60 degree routes follow each profile', () {
      final golden = _fixture(buildSlopesGoldenInputs());
      final grojibGolden = golden.builder.build(_profile(EnemyId.grojib));
      final hashashGolden = golden.builder.build(_profile(EnemyId.hashash));
      final exactFortyFive = golden.surfaces.surfaces.singleWhere(
        (surface) =>
            -surface.outwardNormal.yTicks == 724 &&
            (surface.previousId != null || surface.nextId != null),
      );
      final exactSixty = golden.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(56) &&
            surface.dyTicks.abs() == _ticks(97),
      );

      expect(_hasAnyWalk(grojibGolden, exactFortyFive.id), isTrue);
      expect(_hasAnyWalk(hashashGolden, exactFortyFive.id), isTrue);
      expect(_hasAnyWalk(grojibGolden, exactSixty.id), isFalse);
      expect(_hasAnyWalk(hashashGolden, exactSixty.id), isTrue);

      final between = _fixture(<TerrainPolygonInput>[
        _ground('between', const <(double, double)>[
          (0, 100),
          (40, 100),
          (60, 76),
          (100, 76),
        ]),
      ]);
      final slope = between.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.dxTicks == _ticks(20) && surface.dyTicks == -_ticks(24),
      );
      final grojibBetween = between.builder.build(_profile(EnemyId.grojib));
      final hashashBetween = between.builder.build(_profile(EnemyId.hashash));

      expect(_hasAnyWalk(grojibBetween, slope.id), isFalse);
      expect(_hasAnyWalk(hashashBetween, slope.id), isTrue);
    });

    test('connected slopes and compatible cross-chunk seams emit walk', () {
      final fixture = _fixture(buildSlopesGoldenInputs());
      final graph = fixture.builder.build(_profile(EnemyId.hashash));
      final connectedSlope = fixture.surfaces.surfaces.firstWhere(
        (surface) => surface.dyTicks != 0 && surface.nextId != null,
      );
      final seamSource = fixture.surfaces.surfaces.singleWhere(
        (surface) =>
            surface.id.chunkIndex == 2 && surface.nextId?.chunkIndex == 3,
      );

      expect(
        _hasWalkEdge(graph, connectedSlope.id, connectedSlope.nextId!),
        isTrue,
      );
      expect(_hasWalkEdge(graph, seamSource.id, seamSource.nextId!), isTrue);
      expect(_hasWalkEdge(graph, seamSource.nextId!, seamSource.id), isTrue);
    });
  });

  group('ordinary walk transitions', () {
    test('accepts a 4-pixel step/snap and rejects a 5-pixel transition', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _ground('steps', const <(double, double)>[
          (0, 100),
          (40, 100),
          (40, 96),
          (80, 96),
          (80, 101),
          (120, 101),
        ]),
      ]);
      final graph = fixture.builder.build(_profile(EnemyId.hashash));
      final left = _horizontal(fixture.surfaces, 0, 40, 100);
      final middle = _horizontal(fixture.surfaces, 40, 80, 96);
      final right = _horizontal(fixture.surfaces, 80, 120, 101);

      expect(_hasWalkEdge(graph, left.id, middle.id), isTrue);
      expect(_hasWalkEdge(graph, middle.id, left.id), isTrue);
      expect(_hasWalkEdge(graph, middle.id, right.id), isFalse);
      expect(_hasWalkEdge(graph, right.id, middle.id), isFalse);
    });

    test('blocked, narrow, and steep transitions emit no walk edge', () {
      final blockedFixture = _fixture(<TerrainPolygonInput>[
        _ground('blocked_step', const <(double, double)>[
          (0, 100),
          (40, 100),
          (40, 96),
          (80, 96),
        ]),
        _rectangle('ceiling', 38, 40, 42, 70, shapeIndex: 1),
      ]);
      final blockedGraph = blockedFixture.builder.build(
        _profile(EnemyId.hashash),
      );
      final blockedLeft = _horizontal(blockedFixture.surfaces, 0, 40, 100);
      final blockedRight = _horizontal(blockedFixture.surfaces, 40, 80, 96);
      expect(
        _hasWalkEdge(blockedGraph, blockedLeft.id, blockedRight.id),
        isFalse,
      );

      final narrowFixture = _fixture(<TerrainPolygonInput>[
        _ground('narrow_step', const <(double, double)>[
          (0, 100),
          (40, 100),
          (40, 96),
          (50, 96),
          (50, 100),
          (90, 100),
        ]),
      ]);
      final narrowGraph = narrowFixture.builder.build(_profile(EnemyId.grojib));
      final narrowLeft = _horizontal(narrowFixture.surfaces, 0, 40, 100);
      final narrowTop = _horizontal(narrowFixture.surfaces, 40, 50, 96);
      expect(_hasWalkEdge(narrowGraph, narrowLeft.id, narrowTop.id), isFalse);

      final steepFixture = _fixture(<TerrainPolygonInput>[
        _ground('steep', const <(double, double)>[
          (0, 100),
          (40, 100),
          (60, 76),
          (100, 76),
        ]),
      ]);
      final steepGraph = steepFixture.builder.build(_profile(EnemyId.grojib));
      final steep = steepFixture.surfaces.surfaces.singleWhere(
        (surface) => surface.dyTicks != 0,
      );
      expect(_hasAnyWalk(steepGraph, steep.id), isFalse);
    });

    test('walk cost is source distance divided by authored speed', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _ground('steps', const <(double, double)>[
          (0, 100),
          (40, 100),
          (40, 96),
          (80, 96),
        ]),
      ]);
      final profile = _profile(EnemyId.hashash);
      final graph = fixture.builder.build(profile);
      final left = _horizontal(fixture.surfaces, 0, 40, 100);
      final middle = _horizontal(fixture.surfaces, 40, 80, 96);
      final edge = _edgeBetween(graph, left.id, middle.id)!;

      expect(edge.kind, TerrainSurfaceEdgeKind.walk);
      expect(edge.distanceTicks, _ticks(40));
      expect(edge.travelTicks, 8);
      expect(edge.costUnits, 133333);

      final jump = TerrainSurfaceGraphEdge.airborne(
        to: 1,
        kind: TerrainSurfaceEdgeKind.jump,
        takeoffPoint: TerrainPoint(0, 0),
        landingPoint: TerrainPoint(1, 1),
        commitDirectionX: 1,
        travelTicks: 9,
        simulationTicksPerSecond: 60,
      );
      final drop = TerrainSurfaceGraphEdge.airborne(
        to: 1,
        kind: TerrainSurfaceEdgeKind.drop,
        takeoffPoint: TerrainPoint(0, 0),
        landingPoint: TerrainPoint(1, 1),
        commitDirectionX: 1,
        travelTicks: 9,
        simulationTicksPerSecond: 60,
      );
      expect(jump.costUnits, 150000);
      expect(drop.costUnits, 150000);
    });
  });

  group('sloped jump and drop construction', () {
    test('connects flat/slope and slope/slope landings in both directions', () {
      final flatSlope = _fixture(<TerrainPolygonInput>[
        _ground('flat', const <(double, double)>[(0, 100), (80, 100)]),
        _ground('slope', const <(double, double)>[
          (120, 100),
          (200, 60),
        ], shapeIndex: 1),
      ]);
      final graph = flatSlope.builder.build(_profile(EnemyId.hashash));
      final flat = _surfaceForShape(flatSlope.surfaces, 'flat');
      final slope = _surfaceForShape(flatSlope.surfaces, 'slope');

      expect(
        _hasAirEdge(graph, flat.id, slope.id, TerrainSurfaceEdgeKind.jump),
        isTrue,
      );
      expect(
        _hasAirEdge(graph, slope.id, flat.id, TerrainSurfaceEdgeKind.jump),
        isTrue,
      );

      final slopes = _fixture(<TerrainPolygonInput>[
        _ground('up_slope', const <(double, double)>[(0, 100), (80, 70)]),
        _ground('down_slope', const <(double, double)>[
          (120, 70),
          (200, 100),
        ], shapeIndex: 1),
      ]);
      final slopeGraph = slopes.builder.build(_profile(EnemyId.hashash));
      final up = _surfaceForShape(slopes.surfaces, 'up_slope');
      final down = _surfaceForShape(slopes.surfaces, 'down_slope');
      expect(
        _hasAirEdge(slopeGraph, up.id, down.id, TerrainSurfaceEdgeKind.jump),
        isTrue,
      );
      expect(
        _hasAirEdge(slopeGraph, down.id, up.id, TerrainSurfaceEdgeKind.jump),
        isTrue,
      );
    });

    test('samples uphill and downhill takeoff toward both sides', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _ground('left', const <(double, double)>[(0, 90), (60, 90)]),
        _ground('source_slope', const <(double, double)>[
          (100, 100),
          (180, 70),
        ], shapeIndex: 1),
        _ground('right', const <(double, double)>[
          (220, 80),
          (280, 80),
        ], shapeIndex: 2),
      ]);
      final graph = fixture.builder.build(_profile(EnemyId.hashash));
      final source = _surfaceForShape(fixture.surfaces, 'source_slope');
      final left = _surfaceForShape(fixture.surfaces, 'left');
      final right = _surfaceForShape(fixture.surfaces, 'right');
      final leftEdges = _airEdgesBetween(
        graph,
        source.id,
        left.id,
        TerrainSurfaceEdgeKind.jump,
      );
      final rightEdges = _airEdgesBetween(
        graph,
        source.id,
        right.id,
        TerrainSurfaceEdgeKind.jump,
      );

      expect(leftEdges, isNotEmpty);
      expect(rightEdges, isNotEmpty);
      expect(leftEdges.every((edge) => edge.commitDirectionX == -1), isTrue);
      expect(rightEdges.every((edge) => edge.commitDirectionX == 1), isTrue);
      expect(
        <int>{
          ...leftEdges.map((edge) => edge.takeoffPoint.xTicks),
          ...rightEdges.map((edge) => edge.takeoffPoint.xTicks),
        }.length,
        greaterThan(1),
      );
    });

    test('drops from both true ledges to the first eligible support below', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _ground('lower', const <(double, double)>[(-100, 130), (300, 110)]),
        _rectangle('upper', 40, 60, 160, 90, shapeIndex: 1),
      ]);
      final graph = fixture.builder.build(_profile(EnemyId.hashash));
      final upper = _surfaceForShape(fixture.surfaces, 'upper');
      final lower = _surfaceForShape(fixture.surfaces, 'lower');
      final drops = _airEdgesBetween(
        graph,
        upper.id,
        lower.id,
        TerrainSurfaceEdgeKind.drop,
      );

      expect(drops.map((edge) => edge.commitDirectionX).toSet(), <int>{-1, 1});
      expect(drops.every((edge) => edge.travelTicks > 0), isTrue);
      expect(
        drops.every(
          (edge) => edge.landingPoint.yTicks > edge.takeoffPoint.yTicks,
        ),
        isTrue,
      );
      expect(drops.map((edge) => edge.landingPoint.yTicks).toSet().length, 2);
    });

    test('crosses convex peaks and concave valleys near takeoff', () {
      final convex = _fixture(<TerrainPolygonInput>[
        _ground('convex', const <(double, double)>[
          (0, 100),
          (60, 70),
          (120, 100),
        ]),
        _ground('convex_target', const <(double, double)>[
          (160, 90),
          (220, 90),
        ], shapeIndex: 1),
      ]);
      final convexGraph = convex.builder.build(_profile(EnemyId.hashash));
      final convexTarget = _surfaceForShape(convex.surfaces, 'convex_target');
      final convexSources = convex.surfaces.surfaces.where(
        (surface) => surface.id.shapeId == 'convex',
      );
      expect(
        convexSources.any(
          (source) => _hasAirEdge(
            convexGraph,
            source.id,
            convexTarget.id,
            TerrainSurfaceEdgeKind.jump,
          ),
        ),
        isTrue,
      );

      final concave = _fixture(<TerrainPolygonInput>[
        _ground('concave', const <(double, double)>[
          (0, 70),
          (60, 100),
          (120, 70),
        ]),
        _ground('concave_target', const <(double, double)>[
          (160, 90),
          (220, 90),
        ], shapeIndex: 1),
      ]);
      final concaveGraph = concave.builder.build(_profile(EnemyId.hashash));
      final concaveTarget = _surfaceForShape(
        concave.surfaces,
        'concave_target',
      );
      final concaveSources = concave.surfaces.surfaces.where(
        (surface) => surface.id.shapeId == 'concave',
      );
      expect(
        concaveSources.any(
          (source) => _hasAirEdge(
            concaveGraph,
            source.id,
            concaveTarget.id,
            TerrainSurfaceEdgeKind.jump,
          ),
        ),
        isTrue,
      );
    });

    test('rejects walls and intervening terrain without tunneling', () {
      List<TerrainPolygonInput> base() => <TerrainPolygonInput>[
        _ground('source', const <(double, double)>[(0, 100), (60, 100)]),
        _ground('target', const <(double, double)>[
          (160, 100),
          (220, 100),
        ], shapeIndex: 1),
      ];

      final clear = _fixture(base());
      final clearGraph = clear.builder.build(_profile(EnemyId.hashash));
      final clearSource = _surfaceForShape(clear.surfaces, 'source');
      final clearTarget = _surfaceForShape(clear.surfaces, 'target');
      expect(
        _hasAirEdge(
          clearGraph,
          clearSource.id,
          clearTarget.id,
          TerrainSurfaceEdgeKind.jump,
        ),
        isTrue,
      );

      final walled = _fixture(<TerrainPolygonInput>[
        ...base(),
        _rectangle('wall', 100, -100, 104, 130, shapeIndex: 2),
      ]);
      final walledGraph = walled.builder.build(_profile(EnemyId.hashash));
      expect(
        _hasAirEdge(
          walledGraph,
          _surfaceForShape(walled.surfaces, 'source').id,
          _surfaceForShape(walled.surfaces, 'target').id,
          TerrainSurfaceEdgeKind.jump,
        ),
        isFalse,
      );

      final intervening = _fixture(<TerrainPolygonInput>[
        ...base(),
        _rectangle('intervening', 145, 70, 235, 82, shapeIndex: 2),
      ]);
      final interveningGraph = intervening.builder.build(
        _profile(EnemyId.hashash),
      );
      expect(
        _hasAirEdge(
          interveningGraph,
          _surfaceForShape(intervening.surfaces, 'source').id,
          _surfaceForShape(intervening.surfaces, 'target').id,
          TerrainSurfaceEdgeKind.jump,
        ),
        isFalse,
      );
    });

    test(
      'uses ceiling masks and one-way sidedness during the capsule sweep',
      () {
        final ceiling = _fixture(<TerrainPolygonInput>[
          _ground('source', const <(double, double)>[(0, 100), (60, 100)]),
          _ground('target', const <(double, double)>[
            (160, 100),
            (220, 100),
          ], shapeIndex: 1),
          _rectangle('ceiling', 60, 20, 160, 30, shapeIndex: 2),
        ]);
        final source = _surfaceForShape(ceiling.surfaces, 'source');
        final target = _surfaceForShape(ceiling.surfaces, 'target');
        final ignoredGraph = ceiling.builder.build(_profile(EnemyId.hashash));
        final blockingGraph = ceiling.builder.build(
          _profile(EnemyId.hashash, collideCeilings: true),
        );
        expect(
          _hasAirEdge(
            ignoredGraph,
            source.id,
            target.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isTrue,
        );
        expect(
          _hasAirEdge(
            blockingGraph,
            source.id,
            target.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isFalse,
        );

        final slopedUnderside = _fixture(<TerrainPolygonInput>[
          _ground('underside_source', const <(double, double)>[
            (0, 100),
            (60, 100),
          ]),
          _ground('underside_target', const <(double, double)>[
            (160, 100),
            (220, 100),
          ], shapeIndex: 1),
          _polygon('sloped_underside', const <(double, double)>[
            (60, 10),
            (160, 10),
            (160, 30),
            (60, 55),
          ], shapeIndex: 2),
        ]);
        final undersideGraph = slopedUnderside.builder.build(
          _profile(EnemyId.hashash, collideCeilings: true),
        );
        expect(
          _hasAirEdge(
            undersideGraph,
            _surfaceForShape(slopedUnderside.surfaces, 'underside_source').id,
            _surfaceForShape(slopedUnderside.surfaces, 'underside_target').id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isFalse,
        );

        final oneWay = _fixture(<TerrainPolygonInput>[
          _ground('one_way_source', const <(double, double)>[
            (0, 105),
            (80, 105),
          ]),
          _rectangle(
            'one_way_target',
            120,
            60,
            170,
            64,
            shapeIndex: 1,
            collisionMode: TerrainCollisionMode.oneWay,
          ),
        ]);
        final oneWayGraph = oneWay.builder.build(_profile(EnemyId.hashash));
        expect(
          _hasAirEdge(
            oneWayGraph,
            _surfaceForShape(oneWay.surfaces, 'one_way_source').id,
            _surfaceForShape(oneWay.surfaces, 'one_way_target').id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isTrue,
        );
      },
    );

    test(
      'accepts thin and limit landings and resolves equal-time ties by ID',
      () {
        final thin = _fixture(<TerrainPolygonInput>[
          _ground('source', const <(double, double)>[(0, 100), (80, 100)]),
          _ground('thin', const <(double, double)>[
            (130, 90),
            (140, 90),
          ], shapeIndex: 1),
          _ground('limit', const <(double, double)>[
            (180, 100),
            (208, 51.5),
          ], shapeIndex: 2),
        ]);
        final hashashGraph = thin.builder.build(_profile(EnemyId.hashash));
        final grojibGraph = thin.builder.build(_profile(EnemyId.grojib));
        final source = _surfaceForShape(thin.surfaces, 'source');
        final thinTarget = _surfaceForShape(thin.surfaces, 'thin');
        final limit = _surfaceForShape(thin.surfaces, 'limit');
        expect(
          _hasAirEdge(
            hashashGraph,
            source.id,
            thinTarget.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isTrue,
        );
        expect(
          _hasAirEdge(
            hashashGraph,
            source.id,
            limit.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isTrue,
        );
        expect(
          grojibGraph.eligibility[grojibGraph.indexOfSurfaceId(limit.id)!],
          isFalse,
        );

        final tiedInputs = <TerrainPolygonInput>[
          _ground('tie_source', const <(double, double)>[(0, 100), (80, 100)]),
          _ground('tie_a', const <(double, double)>[
            (130, 90),
            (160, 70),
          ], shapeIndex: 1),
          _ground('tie_b', const <(double, double)>[
            (160, 70),
            (190, 90),
          ], shapeIndex: 2),
        ];
        final tied = _fixture(tiedInputs);
        final tiedGraph = tied.builder.build(_profile(EnemyId.hashash));
        final tiedReversed = _fixture(tiedInputs.reversed.toList());
        final tiedReversedGraph = tiedReversed.builder.build(
          _profile(EnemyId.hashash),
        );
        final tieSource = _surfaceForShape(tied.surfaces, 'tie_source');
        final tieTargets =
            tied.surfaces.surfaces
                .where(
                  (surface) =>
                      surface.id.shapeId.startsWith('tie_') &&
                      surface.id.shapeId != 'tie_source',
                )
                .toList()
              ..sort((left, right) => left.id.compareTo(right.id));
        final tieEdges = tieTargets
            .expand(
              (target) => _airEdgesBetween(
                tiedGraph,
                tieSource.id,
                target.id,
                TerrainSurfaceEdgeKind.jump,
              ),
            )
            .toList();
        expect(
          tieEdges.any((edge) {
            final capsuleX =
                edge.landingPoint.xTicks + _ticks(-1) * edge.commitDirectionX;
            return (capsuleX - _ticks(160)).abs() <= terrainContactEpsilonTicks;
          }),
          isTrue,
        );
        expect(
          _airEdgesBetween(
            tiedGraph,
            tieSource.id,
            tieTargets.first.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isNotEmpty,
        );
        expect(
          _airEdgesBetween(
            tiedGraph,
            tieSource.id,
            tieTargets.last.id,
            TerrainSurfaceEdgeKind.jump,
          ),
          isNotEmpty,
        );
        expect(tiedGraph.signature(), tiedReversedGraph.signature());
      },
    );
  });

  test(
    'repeated builds and input permutations produce identical CSR records',
    () {
      final inputs = <TerrainPolygonInput>[
        _ground('left', const <(double, double)>[
          (0, 100),
          (40, 100),
          (60, 80),
        ]),
        _ground('right', const <(double, double)>[
          (60, 80),
          (100, 80),
          (120, 100),
        ], shapeIndex: 1),
      ];
      final forward = _fixture(inputs);
      final reverse = _fixture(inputs.reversed.toList());
      final profile = _profile(EnemyId.hashash);
      final first = forward.builder.build(profile);
      final repeated = forward.builder.build(profile);
      final permuted = reverse.builder.build(profile);

      expect(first.edgeOffsets, orderedEquals(repeated.edgeOffsets));
      expect(
        first.canonicalRecords(),
        orderedEquals(repeated.canonicalRecords()),
      );
      expect(
        first.canonicalRecords(),
        orderedEquals(permuted.canonicalRecords()),
      );
      expect(first.signature(), repeated.signature());
      expect(first.signature(), permuted.signature());
    },
  );

  test('publication rejects separately rebuilt node instances', () {
    final first = _fixture(<TerrainPolygonInput>[
      _rectangle('floor', 0, 100, 100, 140),
    ]);
    final second = _fixture(<TerrainPolygonInput>[
      _rectangle('floor', 0, 100, 100, 140),
    ]);

    expect(
      () => TerrainSurfaceGraphPublication(<TerrainSurfaceGraph>[
        first.builder.build(_profile(EnemyId.grojib)),
        second.builder.build(_profile(EnemyId.hashash)),
      ]),
      throwsArgumentError,
    );
  });
}

typedef _GraphFixture = ({
  TerrainGeometry geometry,
  TerrainSurfaceSet surfaces,
  TerrainPlacementQuery query,
  TerrainSurfaceGraphBuilder builder,
});

_GraphFixture _fixture(List<TerrainPolygonInput> inputs) {
  final geometry = const TerrainCompiler().compile(inputs, geometryVersion: 7);
  final surfaces = const TerrainSurfaceExtractor().extract(geometry);
  final query = TerrainPlacementQuery(
    geometry: geometry,
    terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
    surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaces),
  );
  return (
    geometry: geometry,
    surfaces: surfaces,
    query: query,
    builder: TerrainSurfaceGraphBuilder(placementQuery: query),
  );
}

TerrainSurfaceGraphBuildProfile _profile(EnemyId id, {bool? collideCeilings}) {
  const catalog = EnemyCatalog();
  final terrain = catalog.terrainContactProfile(id);
  final capsule = terrain.capsule;
  final baseTraversal = terrain.traversal;
  final traversal = collideCeilings == null
      ? baseTraversal
      : TerrainTraversalProfile(
          enabled: baseTraversal.enabled,
          isKinematic: baseTraversal.isKinematic,
          useGravity: baseTraversal.useGravity,
          gravityScaleBp: baseTraversal.gravityScaleBp,
          collideCeilings: collideCeilings,
          collideLeftWalls: baseTraversal.collideLeftWalls,
          collideRightWalls: baseTraversal.collideRightWalls,
          maxWalkableSlopeAngleUnits: baseTraversal.maxWalkableSlopeAngleUnits,
          minimumSupportUpComponent: baseTraversal.minimumSupportUpComponent,
          stepHeightTicks: baseTraversal.stepHeightTicks,
          snapDistanceTicks: baseTraversal.snapDistanceTicks,
          oneWaySupportEnabled: baseTraversal.oneWaySupportEnabled,
          dropThroughEnabled: baseTraversal.dropThroughEnabled,
          groundedMobilityHelpersEnabled:
              baseTraversal.groundedMobilityHelpersEnabled,
          slopeSpeedPoints: baseTraversal.slopeSpeedPoints,
        );
  return TerrainSurfaceGraphBuildProfile(
    profileKey: id.name,
    traversalProfile: traversal,
    radiusTicks: capsule.radiusTicks,
    verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
    authoredOffsetXTicks: capsule.offsetXTicks,
    offsetYTicks: capsule.offsetYTicks,
    supportRequirement: const TerrainSupportRequirement.groundedEnemyRuntime(),
    locomotionSpeedTicksPerSecond: _ticks(300),
    jumpTemplate: JumpReachabilityTemplate.build(
      JumpProfile(
        jumpSpeed: 500,
        gravityY: 1200,
        maxAirTicks: 75,
        airSpeedX: 300,
        dtSeconds: 1 / 60,
        agentHalfWidth: capsule.radiusTicks / terrainPhysicsTicksPerWorldUnit,
        agentHalfHeight:
            (capsule.radiusTicks + capsule.verticalHalfSegmentTicks) /
            terrainPhysicsTicksPerWorldUnit,
        requiredSupportFraction: 1 / 3,
        collideCeilings: traversal.collideCeilings,
        collideLeftWalls: traversal.collideLeftWalls,
        collideRightWalls: traversal.collideRightWalls,
      ),
    ),
  );
}

TerrainNavigationSurface _horizontal(
  TerrainSurfaceSet set,
  double xMin,
  double xMax,
  double y,
) => set.surfaces.singleWhere(
  (surface) =>
      surface.start == TerrainPoint.fromWorld(xMin, y) &&
      surface.end == TerrainPoint.fromWorld(xMax, y),
);

bool _hasAnyWalk(TerrainSurfaceGraph graph, TerrainEdgeId sourceId) {
  final sourceIndex = graph.indexOfSurfaceId(sourceId)!;
  return graph
      .edgesFor(sourceIndex)
      .any((edge) => edge.kind == TerrainSurfaceEdgeKind.walk);
}

bool _hasWalkEdge(
  TerrainSurfaceGraph graph,
  TerrainEdgeId sourceId,
  TerrainEdgeId targetId,
) => _edgeBetween(graph, sourceId, targetId) != null;

TerrainSurfaceGraphEdge? _edgeBetween(
  TerrainSurfaceGraph graph,
  TerrainEdgeId sourceId,
  TerrainEdgeId targetId,
) {
  final sourceIndex = graph.indexOfSurfaceId(sourceId)!;
  final targetIndex = graph.indexOfSurfaceId(targetId)!;
  for (final edge in graph.edgesFor(sourceIndex)) {
    if (edge.kind == TerrainSurfaceEdgeKind.walk && edge.to == targetIndex) {
      return edge;
    }
  }
  return null;
}

TerrainNavigationSurface _surfaceForShape(
  TerrainSurfaceSet set,
  String shapeId,
) => set.surfaces.singleWhere((surface) => surface.id.shapeId == shapeId);

bool _hasAirEdge(
  TerrainSurfaceGraph graph,
  TerrainEdgeId sourceId,
  TerrainEdgeId targetId,
  TerrainSurfaceEdgeKind kind,
) => _airEdgesBetween(graph, sourceId, targetId, kind).isNotEmpty;

List<TerrainSurfaceGraphEdge> _airEdgesBetween(
  TerrainSurfaceGraph graph,
  TerrainEdgeId sourceId,
  TerrainEdgeId targetId,
  TerrainSurfaceEdgeKind kind,
) {
  final sourceIndex = graph.indexOfSurfaceId(sourceId)!;
  final targetIndex = graph.indexOfSurfaceId(targetId)!;
  return graph
      .edgesFor(sourceIndex)
      .where((edge) => edge.kind == kind && edge.to == targetIndex)
      .toList();
}

TerrainPolygonInput _ground(
  String shapeId,
  List<(double, double)> top, {
  int shapeIndex = 0,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    placementKey: 'shape_$shapeIndex',
    shapeId: shapeId,
  ),
  vertices: <(double, double)>[...top, (top.last.$1, 140), (top.first.$1, 140)],
);

TerrainPolygonInput _rectangle(
  String shapeId,
  double left,
  double top,
  double right,
  double bottom, {
  int shapeIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    placementKey: 'shape_$shapeIndex',
    shapeId: shapeId,
  ),
  collisionMode: collisionMode,
  vertices: <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
);

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  int shapeIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'test',
    placementKey: 'shape_$shapeIndex',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
);

int _ticks(double world) => physicsCoordinateToTicks(world);
