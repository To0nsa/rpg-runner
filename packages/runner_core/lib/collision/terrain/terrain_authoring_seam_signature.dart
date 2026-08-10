import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical record label for scheduler-reachable authored terrain seams.
const String terrainAuthoringSeamSignatureFormat = 'authoring-seams-v1';

/// One directed chunk adjacency that the deterministic scheduler can emit.
///
/// Human-readable diagnostics are deliberately excluded: only scheduler
/// identity and the ordered chunk pair participate in the shared signature.
final class TerrainAuthoringSeamTransition
    implements Comparable<TerrainAuthoringSeamTransition> {
  TerrainAuthoringSeamTransition({
    required this.levelId,
    required this.transitionId,
    required this.leftChunkKey,
    required this.rightChunkKey,
  }) {
    _requireRecordField(levelId, 'levelId');
    _requireRecordField(transitionId, 'transitionId');
    _requireChunkKey(leftChunkKey, 'leftChunkKey');
    _requireChunkKey(rightChunkKey, 'rightChunkKey');
  }

  final String levelId;
  final String transitionId;
  final String leftChunkKey;
  final String rightChunkKey;

  /// Exact v1 record retained for compatibility with the editor golden.
  String get canonicalRecord =>
      '$levelId|$transitionId|$leftChunkKey>$rightChunkKey';

  @override
  int compareTo(TerrainAuthoringSeamTransition other) {
    var order = levelId.compareTo(other.levelId);
    if (order != 0) return order;
    order = transitionId.compareTo(other.transitionId);
    if (order != 0) return order;
    order = leftChunkKey.compareTo(other.leftChunkKey);
    return order != 0 ? order : rightChunkKey.compareTo(other.rightChunkKey);
  }
}

/// Immutable canonical scheduler adjacency set shared across authoring tools.
final class TerrainAuthoringSeamSignature {
  TerrainAuthoringSeamSignature(
    Iterable<TerrainAuthoringSeamTransition> transitions,
  ) : transitions = UnmodifiableListView<TerrainAuthoringSeamTransition>(
        List<TerrainAuthoringSeamTransition>.of(transitions)..sort(),
      ) {
    for (var index = 1; index < this.transitions.length; index += 1) {
      final previous = this.transitions[index - 1];
      final current = this.transitions[index];
      if (previous.compareTo(current) == 0) {
        throw ArgumentError(
          'Duplicate terrain seam transition ${current.canonicalRecord}.',
        );
      }
    }
    canonicalRecord = <String>[
      terrainAuthoringSeamSignatureFormat,
      ...this.transitions.map((transition) => transition.canonicalRecord),
    ].join('\n');
    digest = sha256.convert(utf8.encode(canonicalRecord)).toString();
  }

  final List<TerrainAuthoringSeamTransition> transitions;
  late final String canonicalRecord;
  late final String digest;
}

void _requireRecordField(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
  if (value.contains('|') || value.contains('\n') || value.contains('\r')) {
    throw ArgumentError.value(
      value,
      name,
      'Must not contain a record delimiter or line break.',
    );
  }
}

void _requireChunkKey(String value, String name) {
  _requireRecordField(value, name);
  if (value.contains('>')) {
    throw ArgumentError.value(value, name, 'Must not contain ">".');
  }
}
