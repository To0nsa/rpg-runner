import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../track/chunk_pattern_source.dart';
import '../../util/deterministic_rng.dart';
import 'terrain_authoring_scheduler.dart';

/// Maximum exact authoring graph size, shared by preparation and runtime.
/// Distinct selections grow combinatorially; admission fails before exceeding
/// these budgets instead of substituting an incomplete lookahead.
const terrainConnectionStateCapacity = 32768;
const terrainConnectionEdgeCapacity = 262144;

/// Physical connection facts for one authored chunk. Profile strings must be
/// Core's canonical `TerrainBoundarySignature.physicalRecord` values.
final class TerrainChunkConnection {
  const TerrainChunkConnection({
    required this.entrance,
    required this.exit,
    this.canStart = true,
  });

  final String entrance;
  final String exit;

  /// Whether the level's normal spawn has ground support and clearance here.
  final bool canStart;
}

/// A deterministic scheduling failure, with enough context to repair content.
final class TerrainConnectionException implements Exception {
  const TerrainConnectionException(
    this.code,
    this.message, {
    this.chunkKey,
    this.sectionId,
  });
  final String? chunkKey;
  final String? sectionId;
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

typedef _State = ({
  int phase,
  int section,
  int remaining,
  int previous,
  BigInt used,
});

final class _Edge {
  const _Edge(this.target, this.choice);
  final int target;
  // Chunk index for selection nodes, authored count for length-choice nodes.
  final int choice;
}

final class _Node {
  _Node(this.state);
  final _State state;
  final edges = <_Edge>[];
  final incoming = <int>[];
  bool viable = true;
  String? failure;
  int? failedState;
  bool get choosesLength => state.remaining == 0;
}

/// Exact finite-state schedule, including the indefinitely repeating tail.
///
/// Length choices retain every authored count. Chunk choices retain only
/// successors that can continue for every future length choice. The immutable
/// graph is independent of seeds; each consumer creates its own cursor.
final class TerrainConnectionSchedule {
  TerrainConnectionSchedule._(
    this.level,
    this.chunks,
    this._nodes,
    this.contractDigest,
  );

  factory TerrainConnectionSchedule.build({
    required TerrainAuthoringSchedulerLevel level,
    required Iterable<TerrainAuthoringSchedulerChunk> chunks,
    required Map<String, TerrainChunkConnection> connections,
  }) => _Builder(level, chunks, connections).build();

  final TerrainAuthoringSchedulerLevel level;
  final List<TerrainAuthoringSchedulerChunk> chunks;
  final List<_Node> _nodes;

  /// Commits to selection version, schedule settings, membership and profiles.
  final String contractDigest;
  int get stateCount => _nodes.length;
  int get edgeCount =>
      _nodes.fold(0, (count, node) => count + node.edges.length);

  TerrainConnectionCursor cursor(int seed) =>
      TerrainConnectionCursor._(this, seed);

  Set<String> get reachableChunkKeys {
    final seen = <int>{0};
    final pending = <int>[0];
    final keys = <String>{};
    for (var i = 0; i < pending.length; i++) {
      final node = _nodes[pending[i]];
      for (final edge in node.edges) {
        if (!_nodes[edge.target].viable) continue;
        if (seen.add(edge.target)) pending.add(edge.target);
        if (!node.choosesLength) keys.add(chunks[edge.choice].chunkKey);
      }
    }
    return Set.unmodifiable(keys);
  }

  /// Reachable directed pairs after all continuation constraints are applied.
  /// Section occurrence details remain on the graph, not reconstructed from
  /// these pairs when producing a playable witness.
  List<TerrainAuthoringReachableTransition> get transitions {
    final seen = <int>{0};
    final pending = <int>[0];
    final result = <String, TerrainAuthoringReachableTransition>{};
    for (var i = 0; i < pending.length; i++) {
      final node = _nodes[pending[i]];
      for (final edge in node.edges) {
        if (!_nodes[edge.target].viable) continue;
        if (seen.add(edge.target)) pending.add(edge.target);
        if (node.choosesLength || node.state.previous < 0) continue;
        final section = level.assembly?.segments[node.state.section];
        final transition = TerrainAuthoringReachableTransition(
          levelId: level.levelId,
          transitionId:
              'connections-v1:${section?.segmentId ?? 'automatic'}:$contractDigest',
          description:
              'valid continuation in ${section?.segmentId ?? 'automatic progression'}',
          leftChunkKey: chunks[node.state.previous].chunkKey,
          rightChunkKey: chunks[edge.choice].chunkKey,
        );
        result[transition.canonicalRecord] = transition;
      }
    }
    return List.unmodifiable(result.values.toList()..sort());
  }

  /// Explains excluded transitions in reachable occurrences. An empty result
  /// means at least one occurrence permits the pair; it does not promise every
  /// occurrence does. This projection never changes the admitted graph.
  List<String> transitionExclusions(String fromKey, String toKey) {
    final from = chunks.indexWhere((chunk) => chunk.chunkKey == fromKey);
    final to = chunks.indexWhere((chunk) => chunk.chunkKey == toKey);
    if (from < 0 || to < 0) {
      return const ['Chunk is outside the active Level pool.'];
    }
    final reasons = <String>{};
    final seen = <int>{0};
    final pending = <int>[0];
    for (var i = 0; i < pending.length; i++) {
      final node = _nodes[pending[i]];
      for (final edge in node.edges) {
        if (_nodes[edge.target].viable && seen.add(edge.target)) {
          pending.add(edge.target);
        }
      }
      if (node.choosesLength || node.state.previous != from) continue;
      if (node.edges.any(
        (edge) => edge.choice == to && _nodes[edge.target].viable,
      )) {
        return const [];
      }
      final section = level.assembly?.segments[node.state.section];
      final requested =
          section?.difficulty ??
          chunkPatternTierForIndex(
            chunkIndex: node.state.phase,
            earlyPatternChunks: level.earlyPatternChunks,
            easyPatternChunks: level.easyPatternChunks,
            normalPatternChunks: level.normalPatternChunks,
          );
      final pool = chunks.where(
        (chunk) => section == null || chunk.assemblyGroupId == section.groupId,
      );
      final resolved =
          (section?.difficulty == null
                  ? fallbackOrderForTier(requested)
                  : [requested])
              .where((tier) => pool.any((chunk) => chunk.tier == tier))
              .firstOrNull;
      final candidate = chunks[to];
      final reason =
          section != null && candidate.assemblyGroupId != section.groupId
          ? 'requires group ${section.groupId}'
          : candidate.tier != resolved
          ? 'requires ${resolved?.name ?? requested.name} difficulty after pool fallback'
          : section?.requireDistinctChunks == true &&
                node.state.used & (BigInt.one << to) != BigInt.zero
          ? 'already used in this distinct section'
          : node.edges.any((edge) => edge.choice == to)
          ? 'would leave a future section without a continuation'
          : 'physical boundary does not match at this occurrence';
      reasons.add('${section?.segmentId ?? 'Automatic'}: $reason');
    }
    return List.unmodifiable(
      reasons.isEmpty
          ? ['The previous chunk has no reachable occurrence in this Flow.']
          : reasons,
    );
  }

  /// Finds an opening-to-selected path and a continuing loop in complete
  /// scheduling states. Returns null when the selected chunk is unreachable.
  TerrainConnectionWitness? witnessThrough(String chunkKey) {
    final targetChunk = chunks.indexWhere(
      (chunk) => chunk.chunkKey == chunkKey,
    );
    if (targetChunk < 0) return null;
    final parents = <int, (int, _Edge)>{};
    final pending = <int>[0];
    final seen = <int>{0};
    (int, _Edge)? selected;
    for (var i = 0; i < pending.length && selected == null; i++) {
      final current = pending[i];
      final node = _nodes[current];
      for (final edge in node.edges) {
        if (!_nodes[edge.target].viable) continue;
        if (!node.choosesLength && edge.choice == targetChunk) {
          selected = (current, edge);
          break;
        }
        if (seen.add(edge.target)) {
          parents[edge.target] = (current, edge);
          pending.add(edge.target);
        }
      }
    }
    if (selected == null) return null;
    final prefix = <(int, _Edge)>[selected];
    var current = selected.$1;
    while (current != 0) {
      final parent = parents[current]!;
      prefix.add(parent);
      current = parent.$1;
    }
    final keys = <String>[];
    for (final (source, edge) in prefix.reversed) {
      if (!_nodes[source].choosesLength) keys.add(chunks[edge.choice].chunkKey);
    }
    final selectedIndex = keys.length - 1;
    current = selected.$2.target;
    final firstVisit = <int, int>{};
    while (!firstVisit.containsKey(current)) {
      firstVisit[current] = keys.length;
      final node = _nodes[current];
      final edge = node.edges.firstWhere((edge) => _nodes[edge.target].viable);
      if (!node.choosesLength) keys.add(chunks[edge.choice].chunkKey);
      current = edge.target;
    }
    return TerrainConnectionWitness(
      List.unmodifiable(keys),
      selectedIndex,
      firstVisit[current]!,
    );
  }
}

/// A focused tooling sequence whose repeating suffix is proven by state.
final class TerrainConnectionWitness {
  const TerrainConnectionWitness(
    this.chunkKeys,
    this.selectedIndex,
    this.loopStartIndex,
  );
  final List<String> chunkKeys;
  final int selectedIndex;
  final int loopStartIndex;
}

/// One seeded reader with constant storage. Backward queries reset and replay;
/// forward streaming advances once per chunk without retaining run history.
final class TerrainConnectionCursor {
  TerrainConnectionCursor._(this.schedule, this.seed);
  final TerrainConnectionSchedule schedule;
  final int seed;
  int _state = 0;
  int _nextIndex = 0;
  int _runSequence = -1;
  int _runStart = 0;
  int _runLength = 0;
  TerrainConnectionSelection? _last;

  TerrainConnectionSelection selectionFor(int chunkIndex) {
    RangeError.checkNotNegative(chunkIndex, 'chunkIndex');
    if (chunkIndex == _nextIndex - 1 && _last != null) return _last!;
    if (chunkIndex < _nextIndex) {
      _state = 0;
      _nextIndex = 0;
      _runSequence = -1;
      _last = null;
    }
    while (_nextIndex <= chunkIndex) {
      var node = schedule._nodes[_state];
      if (node.choosesLength) {
        _runSequence++;
        final choice = mix32(seed ^ (_runSequence * 0x9e3779b9) ^ 0x27d4eb2d);
        final edge = node.edges[choice % node.edges.length];
        _runStart = _nextIndex;
        _runLength = edge.choice;
        _state = edge.target;
        node = schedule._nodes[_state];
      }
      final choices = node.edges
          .where((edge) => schedule._nodes[edge.target].viable)
          .toList(growable: false);
      final hash = mix32(seed ^ (_nextIndex * 0x9e3779b9) ^ 0x85ebca6b);
      final chosen = choices[hash % choices.length];
      final segments = schedule.level.assembly?.segments;
      final section = segments?[node.state.section];
      final loopAll = schedule.level.assembly?.loopSegments ?? false;
      _last = TerrainConnectionSelection(
        chunk: schedule.chunks[chosen.choice],
        availableChunkKeys: List.unmodifiable(
          choices.map((edge) => schedule.chunks[edge.choice].chunkKey),
        ),
        assembly: section == null
            ? null
            : ChunkAssemblySelection(
                segmentId: section.segmentId,
                segmentIndex: node.state.section,
                runSequence: _runSequence,
                cycleIndex: loopAll
                    ? _runSequence ~/ segments!.length
                    : (_runSequence - segments!.length + 1).clamp(
                        0,
                        _runSequence,
                      ),
                startChunkIndex: _runStart,
                chunkCount: _runLength,
                repeatsFinalSegment:
                    !loopAll && _runSequence >= segments.length,
                difficulty: section.difficulty,
              ),
      );
      _state = chosen.target;
      _nextIndex++;
    }
    return _last!;
  }
}

/// Choice evidence consumed by runtime and occurrence-specific editor previews.
final class TerrainConnectionSelection {
  const TerrainConnectionSelection({
    required this.chunk,
    required this.availableChunkKeys,
    this.assembly,
  });
  final TerrainAuthoringSchedulerChunk chunk;
  final List<String> availableChunkKeys;
  final ChunkAssemblySelection? assembly;
}

final class _Builder {
  _Builder(
    this.level,
    Iterable<TerrainAuthoringSchedulerChunk> source,
    this.connections,
  ) : chunks = List.unmodifiable(
        source.where((c) => c.isActive && c.levelId == level.levelId).toList()
          ..sort((a, b) => a.chunkKey.compareTo(b.chunkKey)),
      );

  final TerrainAuthoringSchedulerLevel level;
  final List<TerrainAuthoringSchedulerChunk> chunks;
  final Map<String, TerrainChunkConnection> connections;
  final nodes = <_Node>[];
  final index = <_State, int>{};
  final _pools = <(int, ChunkPatternTier), Map<String, List<int>>>{};
  int edgeCount = 0;
  late final int hardStart =
      level.assembly?.segments.every((s) => s.difficulty != null) == true
      ? 0
      : level.earlyPatternChunks +
            level.easyPatternChunks +
            level.normalPatternChunks;

  TerrainConnectionSchedule build() {
    if (level.earlyPatternChunks < 0 ||
        level.easyPatternChunks < 0 ||
        level.normalPatternChunks < 0 ||
        level.assembly?.segments.isEmpty == true) {
      _fail(
        'terrain_connection_schedule_invalid',
        'Progression counts must be nonnegative and an ordered Flow must contain a section.',
      );
    }
    if (hardStart < 0 || hardStart > maxTerrainAuthoringFiniteWindowChunks) {
      _fail(
        'terrain_authoring_scheduler_analysis_capacity_exceeded',
        'Progression exceeds the supported $maxTerrainAuthoringFiniteWindowChunks chunk prefix.',
      );
    }
    if (chunks.map((c) => c.chunkKey).toSet().length != chunks.length) {
      _fail(
        'terrain_connection_identity_duplicate',
        'Chunk identities must be unique.',
      );
    }
    for (final chunk in chunks) {
      if (!connections.containsKey(chunk.chunkKey)) {
        _fail(
          'terrain_connection_profile_missing',
          'Missing compiled boundary profiles for ${chunk.chunkKey}.',
        );
      }
    }
    final firstIssue = validateTerrainAuthoringFirstChunk(
      level: level,
      chunks: chunks,
    );
    if (firstIssue != null) _fail(firstIssue.code, firstIssue.message);
    for (final segment
        in level.assembly?.segments ?? <TerrainAuthoringSchedulerSegment>[]) {
      if (segment.minChunkCount < 1 ||
          segment.maxChunkCount < segment.minChunkCount ||
          segment.maxChunkCount > terrainConnectionStateCapacity) {
        _fail(
          'terrain_connection_section_count_invalid',
          'Section ${segment.segmentId} has an unsupported count range.',
        );
      }
    }
    _intern((
      phase: 0,
      section: 0,
      remaining: level.assembly == null ? 1 : 0,
      previous: -1,
      used: BigInt.zero,
    ));
    for (var i = 0; i < nodes.length; i++) {
      _expand(i);
    }
    // Greatest fixed point: a random length node needs every child, while a
    // selectable chunk node needs at least one child. Cycles survive only when
    // all unavoidable exits still have an infinite continuation.
    final liveCounts = [for (final node in nodes) node.edges.length];
    final dead = <int>[];
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].edges.isEmpty) {
        nodes[i].viable = false;
        nodes[i].failedState = i;
        dead.add(i);
      }
    }
    for (var i = 0; i < dead.length; i++) {
      final child = nodes[dead[i]];
      for (final predecessor in child.incoming) {
        final parent = nodes[predecessor];
        if (!parent.viable) continue;
        liveCounts[predecessor]--;
        if (parent.choosesLength || liveCounts[predecessor] == 0) {
          parent.viable = false;
          parent.failure ??= child.failure;
          parent.failedState ??= child.failedState;
          dead.add(predecessor);
        }
      }
    }
    if (!nodes.first.viable) {
      final state = nodes[nodes.first.failedState ?? 0].state;
      throw TerrainConnectionException(
        'terrain_connection_schedule_dead_end',
        'Level ${level.levelId}: ${nodes.first.failure ?? 'No opening permits indefinite continuation.'}',
        chunkKey: state.previous < 0 ? null : chunks[state.previous].chunkKey,
        sectionId: level.assembly?.segments[state.section].segmentId,
      );
    }
    final record = jsonEncode([
      'terrain-connections-v1',
      level.levelId,
      level.earlyPatternChunks,
      level.easyPatternChunks,
      level.normalPatternChunks,
      level.firstChunkKey,
      if (level.assembly case final assembly?)
        [
          assembly.loopSegments,
          for (final section in assembly.segments)
            [
              section.segmentId,
              section.groupId,
              section.difficulty?.name,
              section.minChunkCount,
              section.maxChunkCount,
              section.requireDistinctChunks,
            ],
        ],
      for (final chunk in chunks)
        [
          chunk.chunkKey,
          chunk.tier.name,
          chunk.assemblyGroupId,
          connections[chunk.chunkKey]!.entrance,
          connections[chunk.chunkKey]!.exit,
          connections[chunk.chunkKey]!.canStart,
        ],
    ]);
    return TerrainConnectionSchedule._(
      level,
      chunks,
      nodes,
      sha256.convert(utf8.encode(record)).toString(),
    );
  }

  int _intern(_State state) {
    final existing = index[state];
    if (existing != null) return existing;
    if (nodes.length >= terrainConnectionStateCapacity) {
      _fail(
        'terrain_authoring_scheduler_analysis_capacity_exceeded',
        'Exact connection analysis exceeds $terrainConnectionStateCapacity states. Reduce section length or distinct pool size.',
      );
    }
    final value = nodes.length;
    nodes.add(_Node(state));
    index[state] = value;
    return value;
  }

  void _connect(int source, _State target, int choice) {
    if (++edgeCount > terrainConnectionEdgeCapacity) {
      _fail(
        'terrain_authoring_scheduler_analysis_capacity_exceeded',
        'Exact connection analysis exceeds $terrainConnectionEdgeCapacity transitions.',
      );
    }
    final targetIndex = _intern(target);
    nodes[source].edges.add(_Edge(targetIndex, choice));
    nodes[targetIndex].incoming.add(source);
  }

  void _expand(int source) {
    final node = nodes[source];
    final state = node.state;
    final assembly = level.assembly;
    final section = assembly?.segments[state.section];
    if (node.choosesLength) {
      for (
        var count = section!.minChunkCount;
        count <= section.maxChunkCount;
        count++
      ) {
        _connect(source, (
          phase: state.phase,
          section: state.section,
          remaining: count,
          previous: state.previous,
          used: BigInt.zero,
        ), count);
      }
      return;
    }
    final requested =
        section?.difficulty ??
        chunkPatternTierForIndex(
          chunkIndex: state.phase,
          earlyPatternChunks: level.earlyPatternChunks,
          easyPatternChunks: level.easyPatternChunks,
          normalPatternChunks: level.normalPatternChunks,
        );
    final byEntrance = _pools.putIfAbsent((state.section, requested), () {
      var resolved = <int>[];
      for (final tier
          in section?.difficulty == null
              ? fallbackOrderForTier(requested)
              : [requested]) {
        resolved = [
          for (var i = 0; i < chunks.length; i++)
            if (chunks[i].tier == tier &&
                (section == null ||
                    chunks[i].assemblyGroupId == section.groupId))
              i,
        ];
        if (resolved.isNotEmpty) break;
      }
      final grouped = <String, List<int>>{};
      for (final candidate in resolved) {
        (grouped[connections[chunks[candidate].chunkKey]!.entrance] ??= []).add(
          candidate,
        );
      }
      return grouped;
    });
    final eligible = state.previous < 0
        ? (byEntrance.values.expand((values) => values).toList()..sort())
        : byEntrance[connections[chunks[state.previous].chunkKey]!.exit] ??
              const <int>[];
    for (final candidate in eligible) {
      final chunk = chunks[candidate];
      final connection = connections[chunk.chunkKey]!;
      if (state.previous < 0) {
        if (!connection.canStart ||
            (level.firstChunkKey != null &&
                chunk.chunkKey != level.firstChunkKey)) {
          continue;
        }
      } else if (connections[chunks[state.previous].chunkKey]!.exit !=
          connection.entrance) {
        continue;
      }
      final bit = BigInt.one << candidate;
      if (section?.requireDistinctChunks == true &&
          state.used & bit != BigInt.zero) {
        continue;
      }
      final endSection = section != null && state.remaining == 1;
      final nextSection = !endSection
          ? state.section
          : state.section + 1 < assembly!.segments.length
          ? state.section + 1
          : assembly.loopSegments
          ? 0
          : state.section;
      _connect(source, (
        phase: (state.phase + 1).clamp(0, hardStart),
        section: nextSection,
        remaining: section == null
            ? 1
            : endSection
            ? 0
            : state.remaining - 1,
        previous: candidate,
        used: endSection || section?.requireDistinctChunks != true
            ? BigInt.zero
            : state.used | bit,
      ), candidate);
    }
    if (node.edges.isEmpty) {
      final previous = state.previous < 0
          ? 'Normal spawn'
          : chunks[state.previous].chunkKey;
      node.failure =
          'No valid continuation after $previous in ${section?.segmentId ?? 'Automatic'} ($requested), '
          '${state.remaining} chunk(s) remaining; check the entrance, group, difficulty and already-used chunks.';
    }
  }

  Never _fail(String code, String message) => throw TerrainConnectionException(
    code,
    'Level ${level.levelId}: $message',
  );
}
