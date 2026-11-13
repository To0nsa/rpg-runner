part of '../campaign_tutorial.dart';

/// One dry, flat gap attached to its two direct ground shapes. Geometry stays
/// in compiled terrain; the lesson only authors approach distance and guidance.
final class CampaignGapTutorial extends CampaignPanelTutorial {
  CampaignGapTutorial._(
    super.json, {
    required this.missionChunkId,
    required this.nearGroundShapeId,
    required this.farGroundShapeId,
    required this.approachDistance,
  }) : super._();

  factory CampaignGapTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'gap',
      CampaignTutorialTrigger.gapApproached,
      null,
      extraFields: {
        'missionChunkId',
        'nearGroundShapeId',
        'farGroundShapeId',
        'approachDistance',
      },
    );
    for (final key in [
      'missionChunkId',
      'nearGroundShapeId',
      'farGroundShapeId',
    ]) {
      final id = json[key];
      if (id is! String || !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id)) {
        throw const FormatException(
          'Gap guidance requires a chunk and two ground shapes.',
        );
      }
    }
    if (json['nearGroundShapeId'] == json['farGroundShapeId']) {
      throw const FormatException('Gap banks must be different ground shapes.');
    }
    return CampaignGapTutorial._(
      json,
      missionChunkId: json['missionChunkId']! as String,
      nearGroundShapeId: json['nearGroundShapeId']! as String,
      farGroundShapeId: json['farGroundShapeId']! as String,
      approachDistance: _number(json['approachDistance'], 1, 600),
    );
  }

  @override
  final String missionChunkId;
  final String nearGroundShapeId, farGroundShapeId;
  final double approachDistance;
  @override
  String get kind => 'gap';
  @override
  CampaignTutorialTrigger get trigger => CampaignTutorialTrigger.gapApproached;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.gap;

  /// Uses the captured mission, including unsaved editor geometry. Invalid or
  /// removed banks fail Build/Play even when the lesson is disabled.
  CampaignTutorialGap resolveGap(CampaignMissionDefinition mission) {
    final chunk =
        mission.route.missionChunks[mission.missionChunkIndex(missionChunkId)];
    final gap =
        campaignTutorialGaps(
              mission.terrainCatalog.requireChunk(chunk.pattern.chunkKey!),
            )
            .where(
              (g) =>
                  g.nearGroundShapeId == nearGroundShapeId &&
                  g.farGroundShapeId == farGroundShapeId,
            )
            .firstOrNull;
    if (gap == null) {
      throw FormatException(
        'Tutorial $id: missing dry flat gap $nearGroundShapeId / $farGroundShapeId in $missionChunkId.',
      );
    }
    return gap;
  }

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'missionChunkId': missionChunkId,
      'nearGroundShapeId': nearGroundShapeId,
      'farGroundShapeId': farGroundShapeId,
      'approachDistance': approachDistance,
    });

  static CampaignGapTutorial introduction({
    required String missionChunkId,
    required String nearGroundShapeId,
    required String farGroundShapeId,
    // World units: leave a short, deliberate approach after resuming movement.
    double approachDistance = 96,
  }) => CampaignGapTutorial.decode({
    'id': 'gap_introduction',
    'name': 'Gap crossing',
    'enabled': true,
    'trigger': 'gapApproached',
    'kind': 'gap',
    'missionChunkId': missionChunkId,
    'nearGroundShapeId': nearGroundShapeId,
    'farGroundShapeId': farGroundShapeId,
    'approachDistance': approachDistance,
    'title': {'en': 'Mind the gap', 'fr': 'Attention au vide'},
    'instruction': {
      'en': 'There’s no ground here. Move toward the edge, then jump to the other side. Falling too far ends your attempt. Release, then move again to continue.',
      'fr': 'Il n’y a pas de sol ici. Avance vers le bord, puis saute de l’autre côté. Une chute trop profonde met fin à ta tentative. Relâche puis bouge à nouveau pour continuer.',
    },
    'spotlight': const TutorialSpotlight(
      shape: TutorialSpotlightShape.ellipse,
      x: -0.4,
      y: -0.1,
      width: 1.8,
      height: 1.2,
    ).toJson(),
    'reveals': <String>[],
  });
}

/// Eligible gap in chunk-local world units. The target extends 24 units above
/// and 48 below the ledges so the default spotlight shows the drop and both rims.
final class CampaignTutorialGap {
  const CampaignTutorialGap._({
    required this.nearGroundShapeId,
    required this.farGroundShapeId,
    required this.x,
    required this.y,
    required this.width,
  });
  final String nearGroundShapeId, farGroundShapeId;
  final double x, y, width;
  ({double x, double y, double width, double height}) get bounds =>
      (x: x, y: y - 24, width: width, height: 72);
}

/// Bounded authoring candidates: adjacent rectangular solid ground banks with
/// exposed, level tops and no collision or water spanning the opening. Visual
/// `none` pit dressing is ignored. This is target validation, not a jump solver.
List<CampaignTutorialGap> campaignTutorialGaps(StagedTerrainChunkData chunk) {
  final banks =
      <({StagedTerrainPolygonData polygon, int left, int right, int top})>[];
  for (final polygon in chunk.polygons) {
    if (polygon.id.placementKey != null ||
        polygon.surfaceKind != 'ground' ||
        polygon.collisionMode != StagedTerrainCollisionMode.solid ||
        polygon.vertices.length != 4) {
      continue;
    }
    final xs = polygon.vertices.map((p) => p.xTicks).toSet().toList()..sort();
    final ys = polygon.vertices.map((p) => p.yTicks).toSet().toList()..sort();
    if (xs.length != 2 || ys.length != 2) continue;
    banks.add((
      polygon: polygon,
      left: xs.first,
      right: xs.last,
      top: ys.first,
    ));
  }
  bool exposedTop(StagedTerrainPolygonData polygon, int x, int y) =>
      chunk.edges.any(
        (e) =>
            e.id.sourceId == polygon.id &&
            e.start.yTicks == y &&
            e.end.yTicks == y &&
            e.outwardNormal.yTicks < 0 &&
            (e.start.xTicks == x || e.end.xTicks == x),
      );
  banks.sort((a, b) => a.left.compareTo(b.left));
  final result = <CampaignTutorialGap>[];
  for (var i = 0; i + 1 < banks.length; i++) {
    final near = banks[i], far = banks[i + 1];
    if (near.right >= far.left ||
        near.top != far.top ||
        !exposedTop(near.polygon, near.right, near.top) ||
        !exposedTop(far.polygon, far.left, far.top)) {
      continue;
    }
    final obstructed = chunk.polygons.any(
      (p) =>
          p.collisionMode != StagedTerrainCollisionMode.none &&
          p.vertices.map((v) => v.xTicks).reduce(math.min) < far.left &&
          p.vertices.map((v) => v.xTicks).reduce(math.max) > near.right,
    );
    final x = near.right / terrainPhysicsTicksPerWorldUnit;
    final end = far.left / terrainPhysicsTicksPerWorldUnit;
    if (obstructed ||
        chunk.waterRegions.any((w) => w.x < end && w.x + w.width > x)) {
      continue;
    }
    result.add(
      CampaignTutorialGap._(
        nearGroundShapeId: near.polygon.id.shapeId,
        farGroundShapeId: far.polygon.id.shapeId,
        x: x,
        y: near.top / terrainPhysicsTicksPerWorldUnit,
        width: end - x,
      ),
    );
  }
  return List.unmodifiable(result);
}
