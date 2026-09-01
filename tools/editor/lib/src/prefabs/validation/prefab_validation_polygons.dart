part of 'prefab_validation.dart';

/// Validates one prefab-v3 collision owner without depending on `PrefabDef`.
///
/// Geometry, overlap, and hard limits are delegated to Core. This adapter owns
/// only prefab authoring rules: colliding-kind requirements, canonical source
/// policy, and anchor-relative visual intersection/extent reporting.
List<PrefabValidationIssue> validatePrefabCollisionShapes({
  required String prefabId,
  required String prefabKey,
  required PrefabKind kind,
  required int anchorXPx,
  required int anchorYPx,
  required Iterable<TerrainSourceShapeDef> collisionShapes,
  required int? sourceWidthPx,
  required int? sourceHeightPx,
  required String sourcePath,
}) {
  final shapes = List<TerrainSourceShapeDef>.unmodifiable(collisionShapes);
  final issues = <PrefabValidationIssue>[];

  for (final shape in shapes.where(
    (shape) => shape.collisionMode == TerrainSourceCollisionMode.none,
  )) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_render_only_shape_forbidden',
        message:
            'Prefab $prefabId shape ${shape.shapeId} cannot use no collision; '
            'author render-only terrain directly in a chunk.',
        sourcePath: sourcePath,
        ownerKey: prefabKey,
        shapeId: shape.shapeId,
      ),
    );
  }
  if (issues.isNotEmpty) return _sortedPolygonIssues(issues);

  for (final shape in shapes) {
    final offGrid = shape.vertices.where(
      (vertex) => vertex.xHalfPixels.isOdd || vertex.yHalfPixels.isOdd,
    );
    if (offGrid.isNotEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_collision_shape_not_whole_pixel',
          message:
              'Prefab $prefabId shape ${shape.shapeId} has '
              '${offGrid.length} vertex/vertices outside the whole-pixel '
              'collision grid.',
          sourcePath: sourcePath,
          ownerKey: prefabKey,
          shapeId: shape.shapeId,
        ),
      );
    }
  }

  if (kind == PrefabKind.decoration) {
    if (shapes.isNotEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'decoration_prefab_collision_shape_forbidden',
          message:
              'Prefab $prefabId is decoration and must not include collision shapes.',
          sourcePath: sourcePath,
          ownerKey: prefabKey,
        ),
      );
    }
    return _sortedPolygonIssues(issues);
  }

  if (shapes.isEmpty) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_collision_shape_missing',
        message:
            'Prefab $prefabId has no collision shape and remains non-colliding until reauthored.',
        severity: PrefabValidationSeverity.warning,
        sourcePath: sourcePath,
        ownerKey: prefabKey,
      ),
    );
    return _sortedPolygonIssues(issues);
  }

  final shapeCapacityIssue = prefabShapeSoftTargetIssue(
    prefabLabel: prefabId,
    shapeCount: shapes.length,
    sourcePath: sourcePath,
    ownerKey: prefabKey,
  );
  if (shapeCapacityIssue != null) {
    issues.add(_prefabIssueFromTerrain(shapeCapacityIssue));
  }
  for (final shape in shapes) {
    final vertexCapacityIssue = polygonVertexSoftTargetIssue(
      ownerLabel: 'Prefab $prefabId',
      shapeId: shape.shapeId,
      vertexCount: shape.vertices.length,
      sourcePath: '$sourcePath:${shape.shapeId}',
      ownerKey: prefabKey,
    );
    if (vertexCapacityIssue != null) {
      issues.add(_prefabIssueFromTerrain(vertexCapacityIssue));
    }
  }

  var sourceGeometryAccepted = true;
  for (final shape in shapes) {
    final review = TerrainSourceCoreAdapter.review(
      shape: shape,
      sourcePath: '$sourcePath:${shape.shapeId}',
      chunkIndex: -1,
      chunkKey: prefabKey,
      placementKey: prefabKey,
      requireCanonical: true,
    );
    for (final diagnostic in review.diagnostics) {
      issues.add(_issueFromCore(diagnostic, ownerKey: prefabKey));
      if (terrainDiagnosticIsBlocking(diagnostic)) {
        sourceGeometryAccepted = false;
      }
    }
  }

  if (sourceGeometryAccepted) {
    try {
      const TerrainCompiler().compile(
        shapes.map(
          (shape) => TerrainSourceCoreAdapter.toPolygonInput(
            shape: shape,
            sourcePath: '$sourcePath:${shape.shapeId}',
            chunkIndex: -1,
            chunkKey: prefabKey,
            placementKey: prefabKey,
          ),
        ),
        geometryVersion: 1,
      );
    } on TerrainValidationException catch (error) {
      issues.addAll(
        error.diagnostics.map(
          (diagnostic) => _issueFromCore(diagnostic, ownerKey: prefabKey),
        ),
      );
      sourceGeometryAccepted = false;
    }
  }

  final hasWidth = sourceWidthPx != null;
  final hasHeight = sourceHeightPx != null;
  if (hasWidth != hasHeight) {
    throw ArgumentError(
      'sourceWidthPx and sourceHeightPx must both be provided or both be null.',
    );
  }
  if (!hasWidth || !sourceGeometryAccepted) {
    return _sortedPolygonIssues(issues);
  }
  final widthPx = sourceWidthPx;
  final heightPx = sourceHeightPx!;
  if (widthPx <= 0 || heightPx <= 0) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_visual_bounds_invalid',
        message:
            'Prefab $prefabId resolved non-positive visual bounds '
            '${widthPx}x$heightPx.',
        sourcePath: sourcePath,
        ownerKey: prefabKey,
      ),
    );
    return _sortedPolygonIssues(issues);
  }

  final bounds = _PrefabSourceBounds(
    left: -anchorXPx * 2,
    top: -anchorYPx * 2,
    right: (widthPx - anchorXPx) * 2,
    bottom: (heightPx - anchorYPx) * 2,
  );
  var intersectsVisualSource = false;
  for (final shape in shapes) {
    if (_shapeIntersectsBounds(shape, bounds)) {
      intersectsVisualSource = true;
    }
    final extent = _outsideExtent(shape, bounds);
    if (!extent.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_collision_shape_outside_visual_bounds',
          message:
              'Prefab $prefabId shape ${shape.shapeId} extends outside visual '
              'bounds by ${extent.describe()}; the geometry is preserved.',
          severity: PrefabValidationSeverity.warning,
          sourcePath: sourcePath,
          ownerKey: prefabKey,
          shapeId: shape.shapeId,
        ),
      );
    }
  }
  if (!intersectsVisualSource) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_collision_shapes_outside_visual_source',
        message:
            'Prefab $prefabId must have at least one collision shape with '
            'positive-area intersection with its visual source.',
        sourcePath: sourcePath,
        ownerKey: prefabKey,
      ),
    );
  }
  return _sortedPolygonIssues(issues);
}

PrefabValidationIssue _issueFromCore(
  TerrainDiagnostic diagnostic, {
  required String ownerKey,
}) => _prefabIssueFromTerrain(
  TerrainAuthoringIssue.fromCore(
    diagnostic: diagnostic,
    ownerKey: ownerKey,
    placementKey: null,
  ),
);

PrefabValidationIssue _prefabIssueFromTerrain(TerrainAuthoringIssue issue) =>
    PrefabValidationIssue(
      code: issue.code,
      message: issue.message,
      severity: switch (issue.severity) {
        TerrainAuthoringIssueSeverity.warning =>
          PrefabValidationSeverity.warning,
        TerrainAuthoringIssueSeverity.error => PrefabValidationSeverity.error,
      },
      sourcePath: issue.sourcePath,
      ownerKey: issue.ownerKey,
      shapeId: issue.shapeId ?? '',
      elementIndex: issue.elementIndex ?? 0,
    );

bool _shapeIntersectsBounds(
  TerrainSourceShapeDef shape,
  _PrefabSourceBounds bounds,
) => TerrainPolygonOverlap.sourceLoops(
  shape.vertices
      .map(
        (vertex) => SourceTerrainPoint(vertex.xHalfPixels, vertex.yHalfPixels),
      )
      .toList(growable: false),
  bounds.loop,
);

_OutsideExtent _outsideExtent(
  TerrainSourceShapeDef shape,
  _PrefabSourceBounds bounds,
) {
  final xs = shape.vertices.map((vertex) => vertex.xHalfPixels);
  final ys = shape.vertices.map((vertex) => vertex.yHalfPixels);
  final minX = xs.reduce(math.min);
  final maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  return _OutsideExtent(
    left: math.max(0, bounds.left - minX),
    top: math.max(0, bounds.top - minY),
    right: math.max(0, maxX - bounds.right),
    bottom: math.max(0, maxY - bounds.bottom),
  );
}

List<PrefabValidationIssue> _sortedPolygonIssues(
  Iterable<PrefabValidationIssue> issues,
) => List<PrefabValidationIssue>.unmodifiable(
  List<PrefabValidationIssue>.of(issues)..sort(_compareIssues),
);

final class _PrefabSourceBounds {
  const _PrefabSourceBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  List<SourceTerrainPoint> get loop => <SourceTerrainPoint>[
    SourceTerrainPoint(left, top),
    SourceTerrainPoint(right, top),
    SourceTerrainPoint(right, bottom),
    SourceTerrainPoint(left, bottom),
  ];
}

final class _OutsideExtent {
  const _OutsideExtent({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool get isEmpty => left == 0 && top == 0 && right == 0 && bottom == 0;

  String describe() {
    final parts = <String>[
      if (left > 0) 'left=${_formatHalfPixels(left)}',
      if (top > 0) 'top=${_formatHalfPixels(top)}',
      if (right > 0) 'right=${_formatHalfPixels(right)}',
      if (bottom > 0) 'bottom=${_formatHalfPixels(bottom)}',
    ];
    return parts.join(', ');
  }
}

String _formatHalfPixels(int ticks) =>
    ticks.isEven ? '${ticks ~/ 2} px' : '${ticks ~/ 2}.5 px';
