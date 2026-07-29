import '../../terrain_authoring/terrain_source_models.dart';
import '../models/prefab/prefab_collider_def.dart';

/// One explicitly reviewed replacement for legacy collider geometry that
/// cannot satisfy the accepted polygon contract unchanged.
///
/// The expected collider list is a source-drift guard. A replacement is never
/// applied merely because a prefab key matches.
final class ReviewedLegacyPrefabCollisionReauthoring {
  ReviewedLegacyPrefabCollisionReauthoring({
    required this.prefabKey,
    required Iterable<PrefabColliderDef> expectedColliders,
    required Iterable<TerrainSourceShapeDef> replacementShapes,
    required this.expectedAddedAreaHalfPixelSquared,
    required this.rationale,
  }) : expectedColliders = List<PrefabColliderDef>.unmodifiable(
         expectedColliders,
       ),
       replacementShapes = canonicalTerrainSourceShapes(replacementShapes);

  /// Stable source prefab identity to which this correction belongs.
  final String prefabKey;

  /// Exact ordered collider source reviewed when approving the correction.
  final List<PrefabColliderDef> expectedColliders;

  /// Canonical polygon source that replaces the legacy occupied outline.
  final List<TerrainSourceShapeDef> replacementShapes;

  /// Deliberate outward area addition in half-pixel ticks squared.
  final BigInt expectedAddedAreaHalfPixelSquared;

  /// Reviewable explanation of the local geometry adjustment.
  final String rationale;

  /// Whether [colliders] still exactly match the approved legacy source.
  bool matchesColliders(Iterable<PrefabColliderDef> colliders) {
    final actual = colliders.toList(growable: false);
    if (actual.length != expectedColliders.length) return false;
    for (var index = 0; index < actual.length; index += 1) {
      final left = actual[index];
      final right = expectedColliders[index];
      if (left.offsetX != right.offsetX ||
          left.offsetY != right.offsetY ||
          left.width != right.width ||
          left.height != right.height) {
        return false;
      }
    }
    return true;
  }
}

/// Closed catalog of approved one-time prefab collision corrections.
///
/// These values are migration input, not a second normal authoring source.
/// They are removed after prefab schema v3 has been written and verified.
abstract final class ReviewedLegacyPrefabCollisionReauthorings {
  /// Returns the reviewed correction for [prefabKey], when one is required.
  static ReviewedLegacyPrefabCollisionReauthoring? forPrefabKey(
    String prefabKey,
  ) => _byPrefabKey[prefabKey];

  /// All reviewed corrections in stable prefab-key order.
  static List<ReviewedLegacyPrefabCollisionReauthoring> get all =>
      List<ReviewedLegacyPrefabCollisionReauthoring>.unmodifiable(
        _byPrefabKey.values,
      );

  static final Map<String, ReviewedLegacyPrefabCollisionReauthoring>
  _byPrefabKey = <String, ReviewedLegacyPrefabCollisionReauthoring>{
    'dark_menhir_01': ReviewedLegacyPrefabCollisionReauthoring(
      prefabKey: 'dark_menhir_01',
      expectedColliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: -7, offsetY: -60, width: 18, height: 17),
        PrefabColliderDef(offsetX: 1, offsetY: -26, width: 35, height: 51),
      ],
      replacementShapes: <TerrainSourceShapeDef>[
        _solidShape(<(int, int)>[
          (-33, -137),
          (4, -137),
          (4, -103),
          (37, -103),
          (37, -1),
          (-33, -1),
        ]),
      ],
      expectedAddedAreaHalfPixelSquared: BigInt.from(34),
      rationale:
          'Extend the upper stone 0.5 px left to remove its 0.5 px ledge.',
    ),
    'dark_menhir_03': ReviewedLegacyPrefabCollisionReauthoring(
      prefabKey: 'dark_menhir_03',
      expectedColliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: -6, offsetY: -17, width: 23, height: 37),
        PrefabColliderDef(offsetX: 10, offsetY: -12, width: 16, height: 26),
      ],
      replacementShapes: <TerrainSourceShapeDef>[
        _solidShape(<(int, int)>[
          (-35, -71),
          (11, -71),
          (11, -50),
          (36, -50),
          (36, 3),
          (-35, 3),
        ]),
      ],
      expectedAddedAreaHalfPixelSquared: BigInt.from(25),
      rationale:
          'Extend the right stone 0.5 px down to remove its 0.5 px ledge.',
    ),
    'ruin_stone_00': ReviewedLegacyPrefabCollisionReauthoring(
      prefabKey: 'ruin_stone_00',
      expectedColliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: -5, offsetY: -117, width: 9, height: 19),
        PrefabColliderDef(offsetX: -3, offsetY: -55, width: 14, height: 107),
      ],
      replacementShapes: <TerrainSourceShapeDef>[
        _solidShape(<(int, int)>[
          (-20, -253),
          (-1, -253),
          (-1, -217),
          (8, -217),
          (8, -3),
          (-20, -3),
        ]),
      ],
      expectedAddedAreaHalfPixelSquared: BigInt.from(36),
      rationale:
          'Extend the upper stone 0.5 px left to remove its 0.5 px ledge.',
    ),
  };
}

TerrainSourceShapeDef _solidShape(List<(int, int)> vertices) =>
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: vertices.map(
        (vertex) => TerrainSourceVertexDef(
          xHalfPixels: vertex.$1,
          yHalfPixels: vertex.$2,
        ),
      ),
    );
