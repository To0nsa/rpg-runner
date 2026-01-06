import '../collision/static_world_geometry.dart';
import '../enemies/enemy_id.dart';
import '../tuning/v0_track_tuning.dart';

typedef SpawnEnemy = void Function(EnemyId enemyId, double x);

class V0TrackSpawnedChunk {
  const V0TrackSpawnedChunk({
    required this.index,
    required this.startX,
  });

  final int index;
  final double startX;
}

class V0TrackStreamStepResult {
  const V0TrackStreamStepResult({
    required this.changed,
    required this.spawnedChunks,
  });

  final bool changed;
  final List<V0TrackSpawnedChunk> spawnedChunks;
}

class V0ChunkPattern {
  const V0ChunkPattern({
    required this.name,
    this.platforms = const <_PlatformRel>[],
    this.obstacles = const <_ObstacleRel>[],
    this.groundGaps = const <_GapRel>[],
    this.spawnMarkers = const <_SpawnMarker>[],
  });

  final String name;
  final List<_PlatformRel> platforms;
  final List<_ObstacleRel> obstacles;
  final List<_GapRel> groundGaps;
  final List<_SpawnMarker> spawnMarkers;
}

class V0TrackStreamer {
  V0TrackStreamer({
    required this.seed,
    required this.tuning,
    required this.groundTopY,
  }) : _nextChunkIndex = 0,
       _nextChunkStartX = 0.0;

  final int seed;
  final V0TrackTuning tuning;
  final double groundTopY;

  int _nextChunkIndex;
  double _nextChunkStartX;

  final List<_ActiveChunk> _active = <_ActiveChunk>[];
  List<StaticSolid> _dynamicSolids = const <StaticSolid>[];
  List<StaticGroundSegment> _dynamicGroundSegments =
      const <StaticGroundSegment>[];
  List<StaticGroundGap> _dynamicGroundGaps = const <StaticGroundGap>[];

  /// Current streamed solids (excluding any caller-provided base solids).
  List<StaticSolid> get dynamicSolids => _dynamicSolids;

  /// Current streamed ground segments (excluding any base segments).
  List<StaticGroundSegment> get dynamicGroundSegments => _dynamicGroundSegments;

  /// Current streamed ground gaps (excluding any base gaps).
  List<StaticGroundGap> get dynamicGroundGaps => _dynamicGroundGaps;

  /// Advances chunk streaming based on the current camera bounds.
  ///
  /// Returns a step result (spawned chunks + whether geometry changed).
  V0TrackStreamStepResult step({
    required double cameraLeft,
    required double cameraRight,
    required SpawnEnemy spawnEnemy,
  }) {
    if (!tuning.enabled) {
      return const V0TrackStreamStepResult(
        changed: false,
        spawnedChunks: <V0TrackSpawnedChunk>[],
      );
    }

    var changed = false;
    final spawnedChunks = <V0TrackSpawnedChunk>[];

    // Spawn new chunks ahead of the camera.
    final spawnLimitX = cameraRight + tuning.spawnAheadMargin;
    while (_nextChunkStartX <= spawnLimitX) {
      final chunkIndex = _nextChunkIndex;
      final startX = _nextChunkStartX;
      final endX = startX + tuning.chunkWidth;

      final pattern = _patternFor(seed, chunkIndex);
      final solids = _buildSolids(
        pattern,
        chunkStartX: startX,
        chunkIndex: chunkIndex,
      );
      final ground = _buildGroundSegments(
        pattern,
        chunkStartX: startX,
        chunkIndex: chunkIndex,
      );
      _active.add(
        _ActiveChunk(
          index: chunkIndex,
          startX: startX,
          endX: endX,
          solids: solids,
          groundSegments: ground.segments,
          groundGaps: ground.gaps,
        ),
      );
      spawnedChunks.add(
        V0TrackSpawnedChunk(index: chunkIndex, startX: startX),
      );

      _spawnEnemiesForChunk(
        pattern,
        chunkIndex,
        chunkStartX: startX,
        spawnEnemy: spawnEnemy,
      );

      _nextChunkIndex += 1;
      _nextChunkStartX += tuning.chunkWidth;
      changed = true;
    }

    // Cull old chunks behind the camera.
    final cullLimitX = cameraLeft - tuning.cullBehindMargin;
    while (_active.isNotEmpty && _active.first.endX < cullLimitX) {
      _active.removeAt(0);
      changed = true;
    }

    if (changed) {
      final rebuilt = <StaticSolid>[];
      final rebuiltGroundSegments = <StaticGroundSegment>[];
      final rebuiltGroundGaps = <StaticGroundGap>[];
      for (final c in _active) {
        rebuilt.addAll(c.solids);
        rebuiltGroundSegments.addAll(c.groundSegments);
        rebuiltGroundGaps.addAll(c.groundGaps);
      }
      _dynamicSolids = List<StaticSolid>.unmodifiable(rebuilt);
      _dynamicGroundSegments =
          List<StaticGroundSegment>.unmodifiable(rebuiltGroundSegments);
      _dynamicGroundGaps =
          List<StaticGroundGap>.unmodifiable(rebuiltGroundGaps);
    }

    return V0TrackStreamStepResult(
      changed: changed,
      spawnedChunks: List<V0TrackSpawnedChunk>.unmodifiable(spawnedChunks),
    );
  }

  void _spawnEnemiesForChunk(
    V0ChunkPattern pattern,
    int chunkIndex, {
    required double chunkStartX,
    required SpawnEnemy spawnEnemy,
  }) {
    // Safety: keep the early run empty so the player isn't immediately swarmed.
    if (chunkIndex < 3) return;

    for (var i = 0; i < pattern.spawnMarkers.length; i += 1) {
      final m = pattern.spawnMarkers[i];
      assert(
        _withinChunk(m.x, 0.0),
        'Spawn marker out of chunk bounds: ${pattern.name}',
      );
      assert(_snapped(m.x), 'Spawn marker not snapped to grid: ${pattern.name}');
      final roll = _mix32(
        seed ^ (chunkIndex * 0x9e3779b9) ^ (i * 0x85ebca6b) ^ m.salt,
      );
      if ((roll % 100) >= m.chancePercent) continue;

      final x = chunkStartX + m.x;
      spawnEnemy(m.enemyId, x);
    }
  }

  List<StaticSolid> _buildSolids(
    V0ChunkPattern pattern, {
    required double chunkStartX,
    required int chunkIndex,
  }) {
    // Preserve author ordering for determinism (pattern order, then chunk order).
    final solids = <StaticSolid>[];
    var localSolidIndex = 0;

    for (final p in pattern.platforms) {
      assert(
        _withinChunk(p.x, p.width),
        'Platform out of chunk bounds: ${pattern.name}',
      );
      assert(_snapped(p.x) && _snapped(p.width) && _snapped(p.aboveGroundTop),
          'Platform not snapped to grid: ${pattern.name}');
      final topY = groundTopY - p.aboveGroundTop;
      solids.add(
        StaticSolid(
          minX: chunkStartX + p.x,
          minY: topY,
          maxX: chunkStartX + p.x + p.width,
          maxY: topY + p.thickness,
          sides: StaticSolid.sideTop,
          oneWayTop: true,
          chunkIndex: chunkIndex,
          localSolidIndex: localSolidIndex,
        ),
      );
      localSolidIndex += 1;
    }

    for (final o in pattern.obstacles) {
      assert(
        _withinChunk(o.x, o.width),
        'Obstacle out of chunk bounds: ${pattern.name}',
      );
      assert(_snapped(o.x) && _snapped(o.width) && _snapped(o.height),
          'Obstacle not snapped to grid: ${pattern.name}');
      solids.add(
        StaticSolid(
          minX: chunkStartX + o.x,
          minY: groundTopY - o.height,
          maxX: chunkStartX + o.x + o.width,
          maxY: groundTopY,
          sides: StaticSolid.sideAll,
          oneWayTop: false,
          chunkIndex: chunkIndex,
          localSolidIndex: localSolidIndex,
        ),
      );
      localSolidIndex += 1;
    }

    return solids;
  }

  _GroundBuildResult _buildGroundSegments(
    V0ChunkPattern pattern, {
    required double chunkStartX,
    required int chunkIndex,
  }) {
    final orderedGaps = List<_GapRel>.from(pattern.groundGaps);
    if (orderedGaps.isNotEmpty) {
      orderedGaps.sort((a, b) => a.x.compareTo(b.x));
    }

    final segments = <StaticGroundSegment>[];
    final gaps = <StaticGroundGap>[];
    var cursor = 0.0;
    var localSegmentIndex = 0;
    var lastGapEnd = -1.0;

    for (final gap in orderedGaps) {
      assert(
        _withinChunk(gap.x, gap.width),
        'Ground gap out of chunk bounds: ${pattern.name}',
      );
      assert(_snapped(gap.x) && _snapped(gap.width),
          'Ground gap not snapped to grid: ${pattern.name}');
      assert(
        gap.x >= lastGapEnd - 1e-6,
        'Ground gap overlaps previous: ${pattern.name}',
      );

      final gapStart = gap.x;
      final gapEnd = gap.x + gap.width;
      if (gapStart > cursor + 1e-6) {
        segments.add(
          StaticGroundSegment(
            minX: chunkStartX + cursor,
            maxX: chunkStartX + gapStart,
            topY: groundTopY,
            chunkIndex: chunkIndex,
            localSegmentIndex: localSegmentIndex,
          ),
        );
        localSegmentIndex += 1;
      }

      gaps.add(
        StaticGroundGap(
          minX: chunkStartX + gapStart,
          maxX: chunkStartX + gapEnd,
        ),
      );

      cursor = gapEnd > cursor ? gapEnd : cursor;
      lastGapEnd = gapEnd;
    }

    if (cursor < tuning.chunkWidth - 1e-6) {
      segments.add(
        StaticGroundSegment(
          minX: chunkStartX + cursor,
          maxX: chunkStartX + tuning.chunkWidth,
          topY: groundTopY,
          chunkIndex: chunkIndex,
          localSegmentIndex: localSegmentIndex,
        ),
      );
    }

    return _GroundBuildResult(segments: segments, gaps: gaps);
  }

  V0ChunkPattern _patternFor(int seed, int chunkIndex) {
    // Mild early-game safety: pick from easier patterns for the first few chunks.
    final isEarly = chunkIndex < 3;
    final pool = isEarly ? _easyPatterns : _allPatterns;
    final h = _mix32(seed ^ (chunkIndex * 0x9e3779b9) ^ 0x27d4eb2d);
    final idx = h % pool.length;
    return pool[idx];
  }

  // === Pattern library (authoring-layer) ===
  //
  // Notes:
  // - All coordinates are relative to the chunk start (x in [0, chunkWidth)).
  // - Y is expressed as "above ground top" (so 48 means 48 units above ground).
  // - Values are authored on a 16-unit grid for stability.

  static const double _t = 16.0; // platform thickness

  static const List<V0ChunkPattern> _easyPatterns = <V0ChunkPattern>[
    V0ChunkPattern(
      name: 'recovery-flat',
      platforms: <_PlatformRel>[],
      obstacles: <_ObstacleRel>[],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[],
    ),
    V0ChunkPattern(
      name: 'single-low-platform',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 160, width: 160, aboveGroundTop: 48, thickness: _t),
      ],
      obstacles: <_ObstacleRel>[],
      groundGaps: <_GapRel>[
        _GapRel(x: 64, width: 96),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 240, chancePercent: 10, salt: 0x11),
      ],
    ),
    V0ChunkPattern(
      name: 'two-low-platforms',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 64, width: 144, aboveGroundTop: 48, thickness: _t),
        _PlatformRel(x: 272, width: 144, aboveGroundTop: 64, thickness: _t),
      ],
      obstacles: <_ObstacleRel>[],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 10, salt: 0x12),
      ],
    ),
  ];

  static const List<V0ChunkPattern> _allPatterns = <V0ChunkPattern>[
    // Recovery / breathers.
    ..._easyPatterns,

    // Platforming (optional; ground is always safe in V0).
    V0ChunkPattern(
      name: 'staggered-mid-platforms',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 48, width: 160, aboveGroundTop: 64, thickness: _t),
        _PlatformRel(x: 256, width: 160, aboveGroundTop: 96, thickness: _t),
      ],
      groundGaps: <_GapRel>[
        _GapRel(x: 248, width: 128),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 352, chancePercent: 17, salt: 0x01),
      ],
    ),
    V0ChunkPattern(
      name: 'triple-runner-platforms',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 32, width: 128, aboveGroundTop: 48, thickness: _t),
        _PlatformRel(x: 192, width: 128, aboveGroundTop: 80, thickness: _t),
        _PlatformRel(x: 352, width: 96, aboveGroundTop: 64, thickness: _t),
      ],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 288, chancePercent: 15, salt: 0x02),
      ],
    ),
    V0ChunkPattern(
      name: 'high-platform-over-obstacle',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 224, width: 192, aboveGroundTop: 112, thickness: _t),
      ],
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 128, width: 48, height: 64),
      ],
      groundGaps: <_GapRel>[
        _GapRel(x: 174, width: 96),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 320, chancePercent: 22, salt: 0x03),
      ],
    ),

    // Obstacles (ground blocks that force a jump/dash).
    V0ChunkPattern(
      name: 'single-block',
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 224, width: 48, height: 64),
      ],
      groundGaps: <_GapRel>[
        _GapRel(x: 128, width: 96),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 320, chancePercent: 17, salt: 0x04),
      ],
    ),
    V0ChunkPattern(
      name: 'double-blocks',
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 160, width: 32, height: 48),
        _ObstacleRel(x: 288, width: 48, height: 64),
      ],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 96, chancePercent: 12, salt: 0x05),
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 352, chancePercent: 15, salt: 0x06),
      ],
    ),
    V0ChunkPattern(
      name: 'low-staircase-platforms',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 48, width: 128, aboveGroundTop: 48, thickness: _t),
        _PlatformRel(x: 208, width: 128, aboveGroundTop: 64, thickness: _t),
        _PlatformRel(x: 368, width: 128, aboveGroundTop: 80, thickness: _t),
      ],
      groundGaps: <_GapRel>[
        _GapRel(x: 300, width: 96),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 112, chancePercent: 15, salt: 0x07),
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 320, chancePercent: 15, salt: 0x08),
      ],
    ),
    V0ChunkPattern(
      name: 'wide-platform-gap',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 32, width: 192, aboveGroundTop: 64, thickness: _t),
        _PlatformRel(x: 288, width: 192, aboveGroundTop: 64, thickness: _t),
      ],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 192, chancePercent: 17, salt: 0x09),
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 15, salt: 0x0A),
      ],
    ),
    V0ChunkPattern(
      name: 'double-obstacle-lane',
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 144, width: 48, height: 64),
        _ObstacleRel(x: 336, width: 48, height: 64),
      ],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 256, chancePercent: 17, salt: 0x0B),
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 80, chancePercent: 12, salt: 0x0C),
      ],
    ),
    V0ChunkPattern(
      name: 'mid-platform-overhang',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 96, width: 160, aboveGroundTop: 96, thickness: _t),
        _PlatformRel(x: 384, width: 128, aboveGroundTop: 64, thickness: _t),
      ],
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 320, width: 64, height: 80),
      ],
      groundGaps: <_GapRel>[],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 176, chancePercent: 15, salt: 0x0D),
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 448, chancePercent: 15, salt: 0x0E),
      ],
    ),
    V0ChunkPattern(
      name: 'tight-platforms',
      platforms: <_PlatformRel>[
        _PlatformRel(x: 32, width: 96, aboveGroundTop: 80, thickness: _t),
        _PlatformRel(x: 160, width: 96, aboveGroundTop: 96, thickness: _t),
        _PlatformRel(x: 288, width: 96, aboveGroundTop: 80, thickness: _t),
      ],
      obstacles: <_ObstacleRel>[
        _ObstacleRel(x: 448, width: 48, height: 64),
      ],
      groundGaps: <_GapRel>[
        _GapRel(x: 112, width: 128)
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 240, chancePercent: 15, salt: 0x0F),
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 480, chancePercent: 12, salt: 0x10),
      ],
    ),
    V0ChunkPattern(
      name: 'ground-gap-small',
      groundGaps: <_GapRel>[
        _GapRel(x: 256, width: 64),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 160, chancePercent: 12, salt: 0x21),
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 416, chancePercent: 12, salt: 0x22),
      ],
    ),
    V0ChunkPattern(
      name: 'ground-gap-wide',
      groundGaps: <_GapRel>[
        _GapRel(x: 224, width: 128),
      ],
      spawnMarkers: <_SpawnMarker>[
        _SpawnMarker(enemyId: EnemyId.flyingEnemy, x: 96, chancePercent: 12, salt: 0x23),
        _SpawnMarker(enemyId: EnemyId.groundEnemy, x: 480, chancePercent: 12, salt: 0x24),
      ],
    ),
  ];

  bool _withinChunk(double x, double width) {
    return x >= 0.0 && (x + width) <= tuning.chunkWidth;
  }

  bool _snapped(double v) {
    final s = tuning.gridSnap;
    final snapped = (v / s).roundToDouble() * s;
    return (v - snapped).abs() < 1e-9;
  }
}

class _ActiveChunk {
  const _ActiveChunk({
    required this.index,
    required this.startX,
    required this.endX,
    required this.solids,
    required this.groundSegments,
    required this.groundGaps,
  });

  final int index;
  final double startX;
  final double endX;
  final List<StaticSolid> solids;
  final List<StaticGroundSegment> groundSegments;
  final List<StaticGroundGap> groundGaps;
}

class _GroundBuildResult {
  const _GroundBuildResult({
    required this.segments,
    required this.gaps,
  });

  final List<StaticGroundSegment> segments;
  final List<StaticGroundGap> gaps;
}

class _PlatformRel {
  const _PlatformRel({
    required this.x,
    required this.width,
    required this.aboveGroundTop,
    required this.thickness,
  }) : assert(width > 0),
       assert(thickness > 0),
       assert(aboveGroundTop > 0);

  final double x;
  final double width;
  final double aboveGroundTop;
  final double thickness;
}

class _ObstacleRel {
  const _ObstacleRel({
    required this.x,
    required this.width,
    required this.height,
  }) : assert(width > 0),
       assert(height > 0);

  final double x;
  final double width;
  final double height;
}

class _GapRel {
  const _GapRel({
    required this.x,
    required this.width,
  }) : assert(width > 0);

  final double x;
  final double width;
}

class _SpawnMarker {
  const _SpawnMarker({
    required this.enemyId,
    required this.x,
    required this.chancePercent,
    required this.salt,
  }) : assert(chancePercent >= 0),
       assert(chancePercent <= 100);

  final EnemyId enemyId;
  final double x;
  final int chancePercent;
  final int salt;
}

int _mix32(int x) {
  // MurmurHash3 finalizer-like mix. Keep it explicitly 32-bit.
  var v = x & 0xffffffff;
  v ^= (v >> 16);
  v = (v * 0x7feb352d) & 0xffffffff;
  v ^= (v >> 15);
  v = (v * 0x846ca68b) & 0xffffffff;
  v ^= (v >> 16);
  return v & 0xffffffff;
}
