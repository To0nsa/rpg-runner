import 'dart:collection';
import 'dart:typed_data';

/// Collision creation choices exposed by the Prefab collision editor.
enum PrefabCollisionCreationMethod {
  rectangle,
  polygon,
  fitVisibleBounds,
  traceVisibleOutline,
  detectPlatformSurface;

  bool get isPixelDerived => switch (this) {
    rectangle || polygon => false,
    fitVisibleBounds || traceVisibleOutline || detectPlatformSurface => true,
  };
}

/// Immutable alpha-only raster in Prefab visual-local pixel coordinates.
final class PrefabAlphaMask {
  PrefabAlphaMask({
    required this.width,
    required this.height,
    required Uint8List alpha,
  }) : alpha = _validatedAlpha(width, height, alpha);

  /// Maximum normalized Prefab raster accepted by the synchronous fitter.
  static const int maximumPixelCount = 1024 * 1024;

  final int width;
  final int height;
  final Uint8List alpha;

  int alphaAt(int x, int y) => alpha[y * width + x];
}

Uint8List _validatedAlpha(int width, int height, Uint8List alpha) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Alpha-mask dimensions must be positive.');
  }
  if (width > PrefabAlphaMask.maximumPixelCount ~/ height) {
    throw ArgumentError(
      'Alpha mask exceeds the ${PrefabAlphaMask.maximumPixelCount} pixel '
      'safety limit.',
    );
  }
  final pixelCount = width * height;
  if (alpha.length != pixelCount) {
    throw ArgumentError.value(
      alpha.length,
      'alpha',
      'Expected $pixelCount alpha samples.',
    );
  }
  return Uint8List.fromList(alpha).asUnmodifiableView();
}

/// Route-local settings for deterministic pixel-derived collision.
final class PrefabCollisionFitSettings {
  const PrefabCollisionFitSettings({
    this.alphaCutoff = 1,
    this.minimumIslandArea = 1,
    this.simplificationTolerancePx = 0,
  });

  final int alphaCutoff;
  final int minimumIslandArea;
  final int simplificationTolerancePx;

  PrefabCollisionFitSettings copyWith({
    int? alphaCutoff,
    int? minimumIslandArea,
    int? simplificationTolerancePx,
  }) => PrefabCollisionFitSettings(
    alphaCutoff: alphaCutoff ?? this.alphaCutoff,
    minimumIslandArea: minimumIslandArea ?? this.minimumIslandArea,
    simplificationTolerancePx:
        simplificationTolerancePx ?? this.simplificationTolerancePx,
  );

  @override
  bool operator ==(Object other) =>
      other is PrefabCollisionFitSettings &&
      other.alphaCutoff == alphaCutoff &&
      other.minimumIslandArea == minimumIslandArea &&
      other.simplificationTolerancePx == simplificationTolerancePx;

  @override
  int get hashCode =>
      Object.hash(alphaCutoff, minimumIslandArea, simplificationTolerancePx);
}

/// One integer pixel-cell-boundary point before anchor-relative conversion.
final class PrefabCollisionFitPoint {
  const PrefabCollisionFitPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is PrefabCollisionFitPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// One simple generated polygon in stable component/partition order.
final class PrefabCollisionFitShape {
  PrefabCollisionFitShape({
    required this.componentIndex,
    required this.partitionIndex,
    required Iterable<PrefabCollisionFitPoint> vertices,
  }) : vertices = List<PrefabCollisionFitPoint>.unmodifiable(vertices);

  final int componentIndex;
  final int partitionIndex;
  final List<PrefabCollisionFitPoint> vertices;
}

/// Stable author-facing diagnostic from mask analysis or fitting.
final class PrefabCollisionFitDiagnostic {
  const PrefabCollisionFitDiagnostic({
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final String code;
  final String message;
  final bool blocking;
}

/// Exact source-mask counts and deterministic candidate coverage evidence.
final class PrefabCollisionFitEvidence {
  const PrefabCollisionFitEvidence({
    required this.thresholdVisiblePixels,
    required this.filteredIslandCount,
    required this.filteredVisiblePixels,
    required this.acceptedVisiblePixels,
    required this.coveredVisiblePixels,
    required this.omittedVisiblePixels,
    required this.coveredTransparentPixels,
    required this.sourceColumns,
    required this.supportedColumns,
    required this.omittedColumns,
    required this.maximumSurfaceDeviationPx,
  });

  const PrefabCollisionFitEvidence.empty()
    : thresholdVisiblePixels = 0,
      filteredIslandCount = 0,
      filteredVisiblePixels = 0,
      acceptedVisiblePixels = 0,
      coveredVisiblePixels = 0,
      omittedVisiblePixels = 0,
      coveredTransparentPixels = 0,
      sourceColumns = 0,
      supportedColumns = 0,
      omittedColumns = 0,
      maximumSurfaceDeviationPx = 0;

  final int thresholdVisiblePixels;
  final int filteredIslandCount;
  final int filteredVisiblePixels;
  final int acceptedVisiblePixels;
  final int coveredVisiblePixels;
  final int omittedVisiblePixels;
  final int coveredTransparentPixels;
  final int sourceColumns;
  final int supportedColumns;
  final int omittedColumns;
  final int maximumSurfaceDeviationPx;
}

/// Pure deterministic output. It never owns persistence or source IDs.
final class PrefabCollisionFitResult {
  PrefabCollisionFitResult({
    required this.method,
    required this.settings,
    required Iterable<PrefabCollisionFitShape> shapes,
    required Iterable<PrefabCollisionFitDiagnostic> diagnostics,
    required this.evidence,
    required Uint8List acceptedPixels,
  }) : shapes = List<PrefabCollisionFitShape>.unmodifiable(shapes),
       diagnostics = List<PrefabCollisionFitDiagnostic>.unmodifiable(
         diagnostics,
       ),
       acceptedPixels = Uint8List.fromList(acceptedPixels).asUnmodifiableView();

  final List<PrefabCollisionFitShape> shapes;
  final List<PrefabCollisionFitDiagnostic> diagnostics;
  final PrefabCollisionFitEvidence evidence;
  final PrefabCollisionCreationMethod method;
  final PrefabCollisionFitSettings settings;

  /// One byte per source pixel: `1` means retained after threshold/filtering.
  final Uint8List acceptedPixels;

  bool get accepted =>
      shapes.isNotEmpty &&
      diagnostics.every((diagnostic) => !diagnostic.blocking);
}

/// Pure-Dart alpha-mask to collision geometry pipeline.
abstract final class PrefabCollisionFitter {
  static PrefabCollisionFitResult generate({
    required PrefabAlphaMask mask,
    required PrefabCollisionCreationMethod method,
    PrefabCollisionFitSettings settings = const PrefabCollisionFitSettings(),
  }) {
    if (!method.isPixelDerived) {
      throw ArgumentError.value(method, 'method', 'Must be pixel-derived.');
    }
    final settingsDiagnostic = _validateSettings(settings);
    if (settingsDiagnostic != null) {
      return PrefabCollisionFitResult(
        method: method,
        settings: settings,
        shapes: const <PrefabCollisionFitShape>[],
        diagnostics: <PrefabCollisionFitDiagnostic>[settingsDiagnostic],
        evidence: const PrefabCollisionFitEvidence.empty(),
        acceptedPixels: Uint8List(mask.width * mask.height),
      );
    }

    final thresholded = Uint8List(mask.width * mask.height);
    var thresholdVisiblePixels = 0;
    for (var index = 0; index < mask.alpha.length; index += 1) {
      if (mask.alpha[index] >= settings.alphaCutoff) {
        thresholded[index] = 1;
        thresholdVisiblePixels += 1;
      }
    }

    final discovered = _discoverComponents(
      thresholded,
      width: mask.width,
      height: mask.height,
    );
    final retained = <_PixelComponent>[];
    var filteredPixels = 0;
    var filteredIslands = 0;
    for (final component in discovered) {
      if (component.pixels.length < settings.minimumIslandArea) {
        filteredPixels += component.pixels.length;
        filteredIslands += 1;
      } else {
        retained.add(component);
      }
    }
    final accepted = Uint8List(mask.width * mask.height);
    for (final component in retained) {
      for (final pixel in component.pixels) {
        accepted[pixel.y * mask.width + pixel.x] = 1;
      }
    }
    final acceptedCount = thresholdVisiblePixels - filteredPixels;
    if (acceptedCount == 0) {
      return PrefabCollisionFitResult(
        method: method,
        settings: settings,
        shapes: const <PrefabCollisionFitShape>[],
        diagnostics: <PrefabCollisionFitDiagnostic>[
          const PrefabCollisionFitDiagnostic(
            code: 'prefab_fit_no_visible_pixels',
            message: 'No pixels remain after the alpha and island filters.',
          ),
        ],
        evidence: PrefabCollisionFitEvidence(
          thresholdVisiblePixels: thresholdVisiblePixels,
          filteredIslandCount: filteredIslands,
          filteredVisiblePixels: filteredPixels,
          acceptedVisiblePixels: 0,
          coveredVisiblePixels: 0,
          omittedVisiblePixels: 0,
          coveredTransparentPixels: 0,
          sourceColumns: 0,
          supportedColumns: 0,
          omittedColumns: 0,
          maximumSurfaceDeviationPx: 0,
        ),
        acceptedPixels: accepted,
      );
    }

    final shapes = switch (method) {
      PrefabCollisionCreationMethod.fitVisibleBounds =>
        <PrefabCollisionFitShape>[_fitBounds(retained)],
      PrefabCollisionCreationMethod.traceVisibleOutline => _traceComponents(
        retained,
        width: mask.width,
        height: mask.height,
        tolerance: settings.simplificationTolerancePx,
      ),
      PrefabCollisionCreationMethod.detectPlatformSurface =>
        _detectPlatformSurfaces(
          retained,
          tolerance: settings.simplificationTolerancePx,
        ),
      PrefabCollisionCreationMethod.rectangle ||
      PrefabCollisionCreationMethod.polygon => throw StateError('Unreachable.'),
    };
    final diagnostics = <PrefabCollisionFitDiagnostic>[];
    if (shapes.length > 64) {
      diagnostics.add(
        PrefabCollisionFitDiagnostic(
          code: 'prefab_fit_shape_capacity_exceeded',
          message:
              'The fit needs ${shapes.length} shapes; the hard limit is 64. '
              'Increase minimum island area or use Fit visible bounds.',
        ),
      );
    }
    for (final shape in shapes) {
      if (shape.vertices.length > 64) {
        diagnostics.add(
          PrefabCollisionFitDiagnostic(
            code: 'prefab_fit_vertex_capacity_exceeded',
            message:
                'Component ${shape.componentIndex + 1} needs '
                '${shape.vertices.length} vertices; the hard limit is 64. '
                'Increase simplification or use Fit visible bounds.',
          ),
        );
      }
    }
    if (method == PrefabCollisionCreationMethod.fitVisibleBounds &&
        retained.length > 1) {
      diagnostics.add(
        const PrefabCollisionFitDiagnostic(
          code: 'prefab_fit_bounds_spans_gaps',
          message: 'Fit visible bounds spans transparent gaps between visible islands.',
          blocking: false,
        ),
      );
    }
    if (shapes.isEmpty) {
      diagnostics.add(
        const PrefabCollisionFitDiagnostic(
          code: 'prefab_fit_geometry_empty',
          message: 'Visible pixels did not produce valid collision geometry.',
        ),
      );
    }

    final coverage = _coverage(
      accepted,
      width: mask.width,
      height: mask.height,
      shapes: shapes,
    );
    final surfaceEvidence =
        method == PrefabCollisionCreationMethod.detectPlatformSurface
        ? _surfaceEvidence(retained, shapes)
        : const _SurfaceEvidence.empty();
    return PrefabCollisionFitResult(
      method: method,
      settings: settings,
      shapes: shapes,
      diagnostics: diagnostics,
      evidence: PrefabCollisionFitEvidence(
        thresholdVisiblePixels: thresholdVisiblePixels,
        filteredIslandCount: filteredIslands,
        filteredVisiblePixels: filteredPixels,
        acceptedVisiblePixels: acceptedCount,
        coveredVisiblePixels: coverage.coveredVisible,
        omittedVisiblePixels: acceptedCount - coverage.coveredVisible,
        coveredTransparentPixels: coverage.coveredTransparent,
        sourceColumns: surfaceEvidence.sourceColumns,
        supportedColumns: surfaceEvidence.supportedColumns,
        omittedColumns: surfaceEvidence.omittedColumns,
        maximumSurfaceDeviationPx: surfaceEvidence.maximumDeviation,
      ),
      acceptedPixels: accepted,
    );
  }

  /// Re-evaluates evidence after local candidate edits or inclusion changes.
  static PrefabCollisionFitEvidence evaluateEvidence({
    required PrefabAlphaMask mask,
    required Uint8List acceptedPixels,
    required Iterable<PrefabCollisionFitShape> shapes,
    required PrefabCollisionCreationMethod method,
    required PrefabCollisionFitEvidence baseline,
  }) {
    if (acceptedPixels.length != mask.width * mask.height) {
      throw ArgumentError('Accepted-mask dimensions no longer match source.');
    }
    final candidates = List<PrefabCollisionFitShape>.unmodifiable(shapes);
    final coverage = _coverage(
      acceptedPixels,
      width: mask.width,
      height: mask.height,
      shapes: candidates,
    );
    final surface =
        method == PrefabCollisionCreationMethod.detectPlatformSurface
        ? _surfaceEvidenceFromAccepted(
            acceptedPixels,
            width: mask.width,
            height: mask.height,
            shapes: candidates,
          )
        : const _SurfaceEvidence.empty();
    return PrefabCollisionFitEvidence(
      thresholdVisiblePixels: baseline.thresholdVisiblePixels,
      filteredIslandCount: baseline.filteredIslandCount,
      filteredVisiblePixels: baseline.filteredVisiblePixels,
      acceptedVisiblePixels: baseline.acceptedVisiblePixels,
      coveredVisiblePixels: coverage.coveredVisible,
      omittedVisiblePixels:
          baseline.acceptedVisiblePixels - coverage.coveredVisible,
      coveredTransparentPixels: coverage.coveredTransparent,
      sourceColumns: surface.sourceColumns,
      supportedColumns: surface.supportedColumns,
      omittedColumns: surface.omittedColumns,
      maximumSurfaceDeviationPx: surface.maximumDeviation,
    );
  }
}

PrefabCollisionFitDiagnostic? _validateSettings(
  PrefabCollisionFitSettings settings,
) {
  if (settings.alphaCutoff < 1 || settings.alphaCutoff > 255) {
    return const PrefabCollisionFitDiagnostic(
      code: 'prefab_fit_alpha_cutoff_invalid',
      message: 'Alpha cutoff must be between 1 and 255.',
    );
  }
  if (settings.minimumIslandArea < 1) {
    return const PrefabCollisionFitDiagnostic(
      code: 'prefab_fit_minimum_island_invalid',
      message: 'Minimum island area must be at least one pixel.',
    );
  }
  if (settings.simplificationTolerancePx < 0) {
    return const PrefabCollisionFitDiagnostic(
      code: 'prefab_fit_simplification_invalid',
      message: 'Simplification tolerance cannot be negative.',
    );
  }
  return null;
}

final class _Pixel {
  const _Pixel(this.x, this.y);

  final int x;
  final int y;
}

final class _PixelComponent {
  _PixelComponent({required this.discoveryIndex, required this.pixels}) {
    minX = pixels.first.x;
    maxX = pixels.first.x;
    minY = pixels.first.y;
    maxY = pixels.first.y;
    for (final pixel in pixels.skip(1)) {
      if (pixel.x < minX) minX = pixel.x;
      if (pixel.x > maxX) maxX = pixel.x;
      if (pixel.y < minY) minY = pixel.y;
      if (pixel.y > maxY) maxY = pixel.y;
    }
  }

  final int discoveryIndex;
  final List<_Pixel> pixels;
  late int minX;
  late int maxX;
  late int minY;
  late int maxY;
}

List<_PixelComponent> _discoverComponents(
  Uint8List pixels, {
  required int width,
  required int height,
}) {
  final visited = Uint8List(pixels.length);
  final components = <_PixelComponent>[];
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      final startIndex = y * width + x;
      if (pixels[startIndex] == 0 || visited[startIndex] != 0) continue;
      final queue = Queue<_Pixel>()..add(_Pixel(x, y));
      visited[startIndex] = 1;
      final componentPixels = <_Pixel>[];
      while (queue.isNotEmpty) {
        final pixel = queue.removeFirst();
        componentPixels.add(pixel);
        for (final neighbor in <_Pixel>[
          _Pixel(pixel.x, pixel.y - 1),
          _Pixel(pixel.x - 1, pixel.y),
          _Pixel(pixel.x + 1, pixel.y),
          _Pixel(pixel.x, pixel.y + 1),
        ]) {
          if (neighbor.x < 0 ||
              neighbor.y < 0 ||
              neighbor.x >= width ||
              neighbor.y >= height) {
            continue;
          }
          final index = neighbor.y * width + neighbor.x;
          if (pixels[index] == 0 || visited[index] != 0) continue;
          visited[index] = 1;
          queue.add(neighbor);
        }
      }
      componentPixels.sort((left, right) {
        final yOrder = left.y.compareTo(right.y);
        return yOrder != 0 ? yOrder : left.x.compareTo(right.x);
      });
      components.add(
        _PixelComponent(
          discoveryIndex: components.length,
          pixels: componentPixels,
        ),
      );
    }
  }
  components.sort((left, right) {
    var order = left.minY.compareTo(right.minY);
    if (order != 0) return order;
    order = left.minX.compareTo(right.minX);
    if (order != 0) return order;
    order = left.maxY.compareTo(right.maxY);
    if (order != 0) return order;
    order = left.maxX.compareTo(right.maxX);
    return order != 0
        ? order
        : left.discoveryIndex.compareTo(right.discoveryIndex);
  });
  return components;
}

PrefabCollisionFitShape _fitBounds(List<_PixelComponent> components) {
  var minX = components.first.minX;
  var minY = components.first.minY;
  var maxX = components.first.maxX;
  var maxY = components.first.maxY;
  for (final component in components.skip(1)) {
    if (component.minX < minX) minX = component.minX;
    if (component.minY < minY) minY = component.minY;
    if (component.maxX > maxX) maxX = component.maxX;
    if (component.maxY > maxY) maxY = component.maxY;
  }
  return PrefabCollisionFitShape(
    componentIndex: 0,
    partitionIndex: 0,
    vertices: _canonical(<PrefabCollisionFitPoint>[
      PrefabCollisionFitPoint(minX, minY),
      PrefabCollisionFitPoint(maxX + 1, minY),
      PrefabCollisionFitPoint(maxX + 1, maxY + 1),
      PrefabCollisionFitPoint(minX, maxY + 1),
    ]),
  );
}

List<PrefabCollisionFitShape> _traceComponents(
  List<_PixelComponent> components, {
  required int width,
  required int height,
  required int tolerance,
}) {
  final shapes = <PrefabCollisionFitShape>[];
  for (
    var componentIndex = 0;
    componentIndex < components.length;
    componentIndex += 1
  ) {
    final component = components[componentIndex];
    final loops = _traceBoundaryLoops(component);
    final outerLoops = loops.where((loop) => _signedArea(loop) > 0).toList();
    final hasHoles = loops.any((loop) => _signedArea(loop) < 0);
    if (!hasHoles && outerLoops.length == 1 && _isSimple(outerLoops.single)) {
      var vertices = _removeCollinear(outerLoops.single);
      if (tolerance > 0) {
        vertices = _simplify(vertices, tolerance);
      }
      shapes.add(
        PrefabCollisionFitShape(
          componentIndex: componentIndex,
          partitionIndex: 0,
          vertices: _canonical(vertices),
        ),
      );
      continue;
    }

    // A source polygon has no inner-ring representation. Stable vertically
    // merged scanline rectangles preserve every visible and transparent cell.
    final rectangles = _partitionIntoRectangles(component);
    for (
      var partitionIndex = 0;
      partitionIndex < rectangles.length;
      partitionIndex += 1
    ) {
      final rectangle = rectangles[partitionIndex];
      shapes.add(
        PrefabCollisionFitShape(
          componentIndex: componentIndex,
          partitionIndex: partitionIndex,
          vertices: _canonical(<PrefabCollisionFitPoint>[
            PrefabCollisionFitPoint(rectangle.left, rectangle.top),
            PrefabCollisionFitPoint(rectangle.right, rectangle.top),
            PrefabCollisionFitPoint(rectangle.right, rectangle.bottom),
            PrefabCollisionFitPoint(rectangle.left, rectangle.bottom),
          ]),
        ),
      );
    }
  }
  return shapes;
}

List<List<PrefabCollisionFitPoint>> _traceBoundaryLoops(
  _PixelComponent component,
) {
  final occupied = <int>{
    for (final pixel in component.pixels) _packed(pixel.x, pixel.y),
  };
  final nextByPoint =
      <PrefabCollisionFitPoint, List<PrefabCollisionFitPoint>>{};
  void addEdge(PrefabCollisionFitPoint start, PrefabCollisionFitPoint end) {
    nextByPoint.putIfAbsent(start, () => <PrefabCollisionFitPoint>[]).add(end);
  }

  for (final pixel in component.pixels) {
    final x = pixel.x;
    final y = pixel.y;
    if (!occupied.contains(_packed(x, y - 1))) {
      addEdge(PrefabCollisionFitPoint(x, y), PrefabCollisionFitPoint(x + 1, y));
    }
    if (!occupied.contains(_packed(x + 1, y))) {
      addEdge(
        PrefabCollisionFitPoint(x + 1, y),
        PrefabCollisionFitPoint(x + 1, y + 1),
      );
    }
    if (!occupied.contains(_packed(x, y + 1))) {
      addEdge(
        PrefabCollisionFitPoint(x + 1, y + 1),
        PrefabCollisionFitPoint(x, y + 1),
      );
    }
    if (!occupied.contains(_packed(x - 1, y))) {
      addEdge(PrefabCollisionFitPoint(x, y + 1), PrefabCollisionFitPoint(x, y));
    }
  }
  for (final ends in nextByPoint.values) {
    ends.sort(_comparePoints);
  }

  final unused = <_DirectedEdge>{
    for (final entry in nextByPoint.entries)
      for (final end in entry.value) _DirectedEdge(entry.key, end),
  };
  final loops = <List<PrefabCollisionFitPoint>>[];
  while (unused.isNotEmpty) {
    final startEdge = unused.reduce((left, right) {
      final startOrder = _comparePoints(left.start, right.start);
      if (startOrder != 0) return startOrder < 0 ? left : right;
      return _comparePoints(left.end, right.end) <= 0 ? left : right;
    });
    final loop = <PrefabCollisionFitPoint>[startEdge.start];
    var edge = startEdge;
    while (true) {
      unused.remove(edge);
      if (edge.end == loop.first) break;
      loop.add(edge.end);
      final candidates = unused
          .where((candidate) => candidate.start == edge.end)
          .toList(growable: false);
      if (candidates.isEmpty) {
        return const <List<PrefabCollisionFitPoint>>[];
      }
      candidates.sort((left, right) => _turnOrder(edge, left, right));
      edge = candidates.first;
    }
    loops.add(_removeCollinear(loop));
  }
  loops.sort((left, right) {
    final leftFirst = _canonical(left).first;
    final rightFirst = _canonical(right).first;
    return _comparePoints(leftFirst, rightFirst);
  });
  return loops;
}

final class _DirectedEdge {
  const _DirectedEdge(this.start, this.end);

  final PrefabCollisionFitPoint start;
  final PrefabCollisionFitPoint end;

  @override
  bool operator ==(Object other) =>
      other is _DirectedEdge && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

int _turnOrder(
  _DirectedEdge incoming,
  _DirectedEdge left,
  _DirectedEdge right,
) {
  final leftRank = _clockwiseTurnRank(incoming, left);
  final rightRank = _clockwiseTurnRank(incoming, right);
  final order = leftRank.compareTo(rightRank);
  return order != 0 ? order : _comparePoints(left.end, right.end);
}

int _clockwiseTurnRank(_DirectedEdge incoming, _DirectedEdge outgoing) {
  final dx = incoming.end.x - incoming.start.x;
  final dy = incoming.end.y - incoming.start.y;
  final nextDx = outgoing.end.x - outgoing.start.x;
  final nextDy = outgoing.end.y - outgoing.start.y;
  final cross = dx * nextDy - dy * nextDx;
  final dot = dx * nextDx + dy * nextDy;
  if (cross > 0) return 0;
  if (dot > 0) return 1;
  if (cross < 0) return 2;
  return 3;
}

final class _IntegerRect {
  const _IntegerRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;
}

List<_IntegerRect> _partitionIntoRectangles(_PixelComponent component) {
  final runsByY = <int, List<(int, int)>>{};
  for (var y = component.minY; y <= component.maxY; y += 1) {
    final xs =
        component.pixels
            .where((pixel) => pixel.y == y)
            .map((pixel) => pixel.x)
            .toList()
          ..sort();
    final runs = <(int, int)>[];
    if (xs.isNotEmpty) {
      var start = xs.first;
      var end = start + 1;
      for (final x in xs.skip(1)) {
        if (x == end) {
          end += 1;
        } else {
          runs.add((start, end));
          start = x;
          end = x + 1;
        }
      }
      runs.add((start, end));
    }
    runsByY[y] = runs;
  }

  final active = <(int, int), _IntegerRect>{};
  final completed = <_IntegerRect>[];
  for (var y = component.minY; y <= component.maxY; y += 1) {
    final currentKeys = runsByY[y]!.toSet();
    for (final key in active.keys.toList(growable: false)) {
      if (!currentKeys.contains(key)) completed.add(active.remove(key)!);
    }
    for (final run in runsByY[y]!) {
      final prior = active[run];
      active[run] = prior == null
          ? _IntegerRect(run.$1, y, run.$2, y + 1)
          : _IntegerRect(prior.left, prior.top, prior.right, y + 1);
    }
  }
  completed.addAll(active.values);
  completed.sort((left, right) {
    var order = left.top.compareTo(right.top);
    if (order != 0) return order;
    order = left.left.compareTo(right.left);
    if (order != 0) return order;
    order = left.bottom.compareTo(right.bottom);
    return order != 0 ? order : left.right.compareTo(right.right);
  });
  return completed;
}

List<PrefabCollisionFitShape> _detectPlatformSurfaces(
  List<_PixelComponent> components, {
  required int tolerance,
}) {
  final shapes = <PrefabCollisionFitShape>[];
  for (
    var componentIndex = 0;
    componentIndex < components.length;
    componentIndex += 1
  ) {
    final component = components[componentIndex];
    final topByX = <int, int>{};
    for (final pixel in component.pixels) {
      final prior = topByX[pixel.x];
      if (prior == null || pixel.y < prior) topByX[pixel.x] = pixel.y;
    }
    final xs = topByX.keys.toList()..sort();
    if (xs.isEmpty) continue;
    var runStart = 0;
    for (var index = 1; index <= xs.length; index += 1) {
      if (index < xs.length && xs[index] == xs[index - 1] + 1) continue;
      final runXs = xs.sublist(runStart, index);
      var profile = <PrefabCollisionFitPoint>[
        PrefabCollisionFitPoint(runXs.first, topByX[runXs.first]!),
      ];
      var priorY = topByX[runXs.first]!;
      for (final x in runXs) {
        final y = topByX[x]!;
        if (y != priorY) {
          profile.add(PrefabCollisionFitPoint(x, priorY));
          profile.add(PrefabCollisionFitPoint(x, y));
          priorY = y;
        }
        profile.add(PrefabCollisionFitPoint(x + 1, y));
      }
      profile = _removeConsecutiveDuplicates(profile);
      if (tolerance > 0) profile = _simplifyOpenProfile(profile, tolerance);
      final bottom = component.maxY + 1;
      final polygon = _removeCollinear(<PrefabCollisionFitPoint>[
        ...profile,
        PrefabCollisionFitPoint(profile.last.x, bottom),
        PrefabCollisionFitPoint(profile.first.x, bottom),
      ]);
      if (polygon.length >= 3 && _signedArea(polygon) > 0) {
        shapes.add(
          PrefabCollisionFitShape(
            componentIndex: componentIndex,
            partitionIndex: shapes
                .where((shape) => shape.componentIndex == componentIndex)
                .length,
            vertices: _canonical(polygon),
          ),
        );
      }
      runStart = index;
    }
  }
  return shapes;
}

List<PrefabCollisionFitPoint> _simplify(
  List<PrefabCollisionFitPoint> source,
  int tolerance,
) {
  var result = List<PrefabCollisionFitPoint>.of(source);
  var changed = true;
  while (changed && result.length > 3) {
    changed = false;
    for (var index = 0; index < result.length; index += 1) {
      final previous = result[(index - 1 + result.length) % result.length];
      final point = result[index];
      final next = result[(index + 1) % result.length];
      if (!_withinTolerance(previous, point, next, tolerance)) continue;
      final candidate = List<PrefabCollisionFitPoint>.of(result)
        ..removeAt(index);
      if (_signedArea(candidate) <= 0 || !_isSimple(candidate)) continue;
      result = candidate;
      changed = true;
      break;
    }
  }
  return result;
}

List<PrefabCollisionFitPoint> _simplifyOpenProfile(
  List<PrefabCollisionFitPoint> source,
  int tolerance,
) {
  var result = List<PrefabCollisionFitPoint>.of(source);
  var changed = true;
  while (changed && result.length > 2) {
    changed = false;
    for (var index = 1; index < result.length - 1; index += 1) {
      if (!_withinTolerance(
        result[index - 1],
        result[index],
        result[index + 1],
        tolerance,
      )) {
        continue;
      }
      result = List<PrefabCollisionFitPoint>.of(result)..removeAt(index);
      changed = true;
      break;
    }
  }
  return result;
}

bool _withinTolerance(
  PrefabCollisionFitPoint start,
  PrefabCollisionFitPoint point,
  PrefabCollisionFitPoint end,
  int tolerance,
) {
  final dx = end.x - start.x;
  final dy = end.y - start.y;
  final cross = dx * (point.y - start.y) - dy * (point.x - start.x);
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return false;
  return cross * cross <= tolerance * tolerance * lengthSquared;
}

List<PrefabCollisionFitPoint> _removeConsecutiveDuplicates(
  List<PrefabCollisionFitPoint> source,
) {
  final result = <PrefabCollisionFitPoint>[];
  for (final point in source) {
    if (result.isEmpty || result.last != point) result.add(point);
  }
  return result;
}

List<PrefabCollisionFitPoint> _removeCollinear(
  List<PrefabCollisionFitPoint> source,
) {
  var points = _removeConsecutiveDuplicates(source);
  if (points.length > 1 && points.first == points.last) {
    points = points.sublist(0, points.length - 1);
  }
  var changed = true;
  while (changed && points.length > 3) {
    changed = false;
    for (var index = 0; index < points.length; index += 1) {
      final previous = points[(index - 1 + points.length) % points.length];
      final current = points[index];
      final next = points[(index + 1) % points.length];
      if ((current.x - previous.x) * (next.y - current.y) ==
          (current.y - previous.y) * (next.x - current.x)) {
        points = List<PrefabCollisionFitPoint>.of(points)..removeAt(index);
        changed = true;
        break;
      }
    }
  }
  return points;
}

List<PrefabCollisionFitPoint> _canonical(List<PrefabCollisionFitPoint> source) {
  if (source.isEmpty) return source;
  var points = _removeCollinear(source);
  if (_signedArea(points) < 0) points = points.reversed.toList();
  var best = 0;
  for (var index = 1; index < points.length; index += 1) {
    final pointOrder = _comparePoints(points[index], points[best]);
    if (pointOrder < 0 ||
        (pointOrder == 0 && _compareCycles(points, index, best) < 0)) {
      best = index;
    }
  }
  return <PrefabCollisionFitPoint>[...points.skip(best), ...points.take(best)];
}

int _compareCycles(List<PrefabCollisionFitPoint> points, int left, int right) {
  for (var offset = 1; offset < points.length; offset += 1) {
    final order = _comparePoints(
      points[(left + offset) % points.length],
      points[(right + offset) % points.length],
    );
    if (order != 0) return order;
  }
  return 0;
}

int _comparePoints(
  PrefabCollisionFitPoint left,
  PrefabCollisionFitPoint right,
) {
  final xOrder = left.x.compareTo(right.x);
  return xOrder != 0 ? xOrder : left.y.compareTo(right.y);
}

int _signedArea(List<PrefabCollisionFitPoint> points) {
  var sum = 0;
  for (var index = 0; index < points.length; index += 1) {
    final current = points[index];
    final next = points[(index + 1) % points.length];
    sum += current.x * next.y - next.x * current.y;
  }
  return sum;
}

bool _isSimple(List<PrefabCollisionFitPoint> points) {
  for (var left = 0; left < points.length; left += 1) {
    final leftNext = (left + 1) % points.length;
    for (var right = left + 1; right < points.length; right += 1) {
      final rightNext = (right + 1) % points.length;
      if (left == right ||
          leftNext == right ||
          rightNext == left ||
          (left == 0 && rightNext == 0)) {
        continue;
      }
      if (_segmentsIntersect(
        points[left],
        points[leftNext],
        points[right],
        points[rightNext],
      )) {
        return false;
      }
    }
  }
  return true;
}

bool _segmentsIntersect(
  PrefabCollisionFitPoint a,
  PrefabCollisionFitPoint b,
  PrefabCollisionFitPoint c,
  PrefabCollisionFitPoint d,
) {
  int orientation(
    PrefabCollisionFitPoint p,
    PrefabCollisionFitPoint q,
    PrefabCollisionFitPoint r,
  ) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);

  final abC = orientation(a, b, c);
  final abD = orientation(a, b, d);
  final cdA = orientation(c, d, a);
  final cdB = orientation(c, d, b);
  if (abC == 0 && _onSegment(a, b, c)) return true;
  if (abD == 0 && _onSegment(a, b, d)) return true;
  if (cdA == 0 && _onSegment(c, d, a)) return true;
  if (cdB == 0 && _onSegment(c, d, b)) return true;
  return (abC < 0) != (abD < 0) && (cdA < 0) != (cdB < 0);
}

bool _onSegment(
  PrefabCollisionFitPoint a,
  PrefabCollisionFitPoint b,
  PrefabCollisionFitPoint point,
) =>
    point.x >= (a.x < b.x ? a.x : b.x) &&
    point.x <= (a.x > b.x ? a.x : b.x) &&
    point.y >= (a.y < b.y ? a.y : b.y) &&
    point.y <= (a.y > b.y ? a.y : b.y);

final class _Coverage {
  const _Coverage(this.coveredVisible, this.coveredTransparent);

  final int coveredVisible;
  final int coveredTransparent;
}

_Coverage _coverage(
  Uint8List accepted, {
  required int width,
  required int height,
  required List<PrefabCollisionFitShape> shapes,
}) {
  final coveredCells = Uint8List(width * height);
  for (final shape in shapes) {
    if (shape.vertices.length < 3) continue;
    var minX = shape.vertices.first.x;
    var minY = shape.vertices.first.y;
    var maxX = minX;
    var maxY = minY;
    for (final point in shape.vertices.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    final firstX = minX.clamp(0, width).toInt();
    final lastX = maxX.clamp(0, width).toInt();
    final firstY = minY.clamp(0, height).toInt();
    final lastY = maxY.clamp(0, height).toInt();
    for (var y = firstY; y < lastY; y += 1) {
      for (var x = firstX; x < lastX; x += 1) {
        final index = y * width + x;
        if (coveredCells[index] == 0 &&
            _polygonIntersectsCell(shape.vertices, x, y)) {
          coveredCells[index] = 1;
        }
      }
    }
  }
  var coveredVisible = 0;
  var coveredTransparent = 0;
  for (var index = 0; index < coveredCells.length; index += 1) {
    if (coveredCells[index] == 0) continue;
    if (accepted[index] != 0) {
      coveredVisible += 1;
    } else {
      coveredTransparent += 1;
    }
  }
  return _Coverage(coveredVisible, coveredTransparent);
}

bool _polygonIntersectsCell(
  List<PrefabCollisionFitPoint> polygon,
  int x,
  int y,
) {
  var clipped = <_DoublePoint>[
    for (final point in polygon)
      _DoublePoint(point.x.toDouble(), point.y.toDouble()),
  ];
  clipped = _clip(clipped, (point) => point.x >= x, (a, b) {
    final t = (x - a.x) / (b.x - a.x);
    return _DoublePoint(x.toDouble(), a.y + (b.y - a.y) * t);
  });
  clipped = _clip(clipped, (point) => point.x <= x + 1, (a, b) {
    final edge = x + 1.0;
    final t = (edge - a.x) / (b.x - a.x);
    return _DoublePoint(edge, a.y + (b.y - a.y) * t);
  });
  clipped = _clip(clipped, (point) => point.y >= y, (a, b) {
    final t = (y - a.y) / (b.y - a.y);
    return _DoublePoint(a.x + (b.x - a.x) * t, y.toDouble());
  });
  clipped = _clip(clipped, (point) => point.y <= y + 1, (a, b) {
    final edge = y + 1.0;
    final t = (edge - a.y) / (b.y - a.y);
    return _DoublePoint(a.x + (b.x - a.x) * t, edge);
  });
  if (clipped.length < 3) return false;
  var area = 0.0;
  for (var index = 0; index < clipped.length; index += 1) {
    final current = clipped[index];
    final next = clipped[(index + 1) % clipped.length];
    area += current.x * next.y - next.x * current.y;
  }
  return area.abs() > 0.000000001;
}

final class _DoublePoint {
  const _DoublePoint(this.x, this.y);

  final double x;
  final double y;
}

List<_DoublePoint> _clip(
  List<_DoublePoint> source,
  bool Function(_DoublePoint point) inside,
  _DoublePoint Function(_DoublePoint start, _DoublePoint end) intersection,
) {
  if (source.isEmpty) return source;
  final result = <_DoublePoint>[];
  var previous = source.last;
  var previousInside = inside(previous);
  for (final current in source) {
    final currentInside = inside(current);
    if (currentInside) {
      if (!previousInside) result.add(intersection(previous, current));
      result.add(current);
    } else if (previousInside) {
      result.add(intersection(previous, current));
    }
    previous = current;
    previousInside = currentInside;
  }
  return result;
}

final class _SurfaceEvidence {
  const _SurfaceEvidence({
    required this.sourceColumns,
    required this.supportedColumns,
    required this.omittedColumns,
    required this.maximumDeviation,
  });

  const _SurfaceEvidence.empty()
    : sourceColumns = 0,
      supportedColumns = 0,
      omittedColumns = 0,
      maximumDeviation = 0;

  final int sourceColumns;
  final int supportedColumns;
  final int omittedColumns;
  final int maximumDeviation;
}

_SurfaceEvidence _surfaceEvidence(
  List<_PixelComponent> components,
  List<PrefabCollisionFitShape> shapes,
) {
  final sourceTop = <int, int>{};
  for (final component in components) {
    for (final pixel in component.pixels) {
      final prior = sourceTop[pixel.x];
      if (prior == null || pixel.y < prior) sourceTop[pixel.x] = pixel.y;
    }
  }
  return _surfaceEvidenceForTop(sourceTop, shapes);
}

_SurfaceEvidence _surfaceEvidenceForTop(
  Map<int, int> sourceTop,
  List<PrefabCollisionFitShape> shapes,
) {
  final candidateTop = <int, _RationalY>{};
  for (final shape in shapes) {
    for (var index = 0; index < shape.vertices.length; index += 1) {
      final start = shape.vertices[index];
      final end = shape.vertices[(index + 1) % shape.vertices.length];
      if (end.x <= start.x) continue;
      final denominator = end.x - start.x;
      for (var x = start.x; x < end.x; x += 1) {
        final y = _RationalY(
          start.y * denominator + (end.y - start.y) * (x - start.x),
          denominator,
        );
        final prior = candidateTop[x];
        if (prior == null || y.compareTo(prior) < 0) candidateTop[x] = y;
      }
    }
  }
  var supported = 0;
  var maxDeviation = 0;
  for (final entry in sourceTop.entries) {
    final candidate = candidateTop[entry.key];
    if (candidate == null) continue;
    supported += 1;
    final differenceNumerator =
        (candidate.numerator - entry.value * candidate.denominator).abs();
    final deviation =
        (differenceNumerator + candidate.denominator - 1) ~/
        candidate.denominator;
    if (deviation > maxDeviation) maxDeviation = deviation;
  }
  return _SurfaceEvidence(
    sourceColumns: sourceTop.length,
    supportedColumns: supported,
    omittedColumns: sourceTop.length - supported,
    maximumDeviation: maxDeviation,
  );
}

final class _RationalY implements Comparable<_RationalY> {
  const _RationalY(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  @override
  int compareTo(_RationalY other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);
}

_SurfaceEvidence _surfaceEvidenceFromAccepted(
  Uint8List accepted, {
  required int width,
  required int height,
  required List<PrefabCollisionFitShape> shapes,
}) {
  final sourceTop = <int, int>{};
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      if (accepted[y * width + x] == 0) continue;
      sourceTop.putIfAbsent(x, () => y);
    }
  }
  return _surfaceEvidenceForTop(sourceTop, shapes);
}

int _packed(int x, int y) => (x << 32) ^ (y & 0xffffffff);
