import 'package:runner_core/collision/terrain/terrain_authoring_polygon_signature.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('records are canonical across input order and snapshot vertices', () {
    final mutableVertices = <SourceTerrainPoint>[
      SourceTerrainPoint(0, 0),
      SourceTerrainPoint(8, 0),
      SourceTerrainPoint(8, 8),
    ];
    final chunk = _record(vertices: mutableVertices);
    final prefab = _record(
      ownerKind: TerrainAuthoringPolygonOwnerKind.prefab,
      ownerKey: 'prefab_ramp',
      ownerId: 'ramp',
      shapeId: 'ramp_shape',
    );
    final expected = terrainAuthoringPolygonSignature(
      <TerrainAuthoringPolygonRecord>[chunk, prefab],
    );

    mutableVertices[0] = SourceTerrainPoint(2, 2);

    expect(
      terrainAuthoringPolygonSignature(<TerrainAuthoringPolygonRecord>[
        prefab,
        chunk,
      ]),
      expected,
    );
    expect(
      canonicalTerrainAuthoringPolygonRecords(<TerrainAuthoringPolygonRecord>[
        prefab,
        chunk,
      ]).first,
      chunk.canonicalRecord(),
    );
  });

  test('every collision-authoring fact participates in the digest', () {
    final baseline = terrainAuthoringPolygonSignature([_record()]);
    final mutations = <TerrainAuthoringPolygonRecord>[
      _record(ownerKind: TerrainAuthoringPolygonOwnerKind.prefab),
      _record(ownerKey: 'chunk_other'),
      _record(ownerId: 'other'),
      _record(ownerRevision: 8),
      _record(shapeId: 'other_shape'),
      _record(collisionMode: TerrainCollisionMode.oneWay),
      _record(surfaceKind: 'ice'),
      _record(materialKey: 'stone'),
      _record(
        vertices: <SourceTerrainPoint>[
          SourceTerrainPoint(0, 0),
          SourceTerrainPoint(10, 0),
          SourceTerrainPoint(8, 8),
        ],
      ),
    ];

    for (final mutation in mutations) {
      expect(terrainAuthoringPolygonSignature([mutation]), isNot(baseline));
    }
  });

  test('empty sets are explicit and duplicate identities fail closed', () {
    expect(
      terrainAuthoringPolygonSignature(const []),
      'e3b0c44298fc1c149afbf4c8996fb924'
      '27ae41e4649b934ca495991b7852b855',
    );
    expect(
      () => terrainAuthoringPolygonSignature([_record(), _record()]),
      throwsArgumentError,
    );
  });
}

TerrainAuthoringPolygonRecord _record({
  TerrainAuthoringPolygonOwnerKind ownerKind =
      TerrainAuthoringPolygonOwnerKind.chunk,
  String ownerKey = 'chunk_fixture',
  String ownerId = 'fixture',
  int ownerRevision = 7,
  String shapeId = 'ground',
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
  String? surfaceKind,
  String? materialKey,
  List<SourceTerrainPoint>? vertices,
}) => TerrainAuthoringPolygonRecord(
  ownerKind: ownerKind,
  ownerKey: ownerKey,
  ownerId: ownerId,
  ownerRevision: ownerRevision,
  shapeId: shapeId,
  vertices:
      vertices ??
      <SourceTerrainPoint>[
        SourceTerrainPoint(0, 0),
        SourceTerrainPoint(8, 0),
        SourceTerrainPoint(8, 8),
      ],
  collisionMode: collisionMode,
  surfaceKind: surfaceKind,
  materialKey: materialKey,
);
