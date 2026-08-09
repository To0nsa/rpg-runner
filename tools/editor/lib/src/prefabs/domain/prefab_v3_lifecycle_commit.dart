import 'package:meta/meta.dart';

import '../models/models.dart';
import '../store/prefab_determinism.dart';
import '../store/prefab_tile_file_codec.dart';
import '../store/prefab_v3_file_codec.dart';
import '../validation/prefab_validation.dart';
import 'prefab_domain_models.dart';
import 'prefab_visual_bounds_resolver.dart';
import 'prefab_v3_owner_validation.dart';

/// Immutable complete-source token for optimistic prefab-v3 lifecycle edits.
///
/// Lifecycle operations can copy owner content and allocate against all stable
/// keys, so freshness covers both canonical source files rather than only the
/// selected owner's display fields.
@immutable
final class PrefabV3LifecycleSnapshot {
  const PrefabV3LifecycleSnapshot._({
    required this.prefabContents,
    required this.tileContents,
  });

  factory PrefabV3LifecycleSnapshot.fromDocument(
    PrefabV3StagingDocument document,
  ) => PrefabV3LifecycleSnapshot._(
    prefabContents: PrefabV3FileCodec.encode(document.data),
    tileContents: PrefabTileFileCodec.encode(document.tileData),
  );

  final String prefabContents;
  final String tileContents;

  @override
  bool operator ==(Object other) =>
      other is PrefabV3LifecycleSnapshot &&
      prefabContents == other.prefabContents &&
      tileContents == other.tileContents;

  @override
  int get hashCode => Object.hash(prefabContents, tileContents);
}

@immutable
sealed class PrefabV3LifecycleOperation {
  const PrefabV3LifecycleOperation();
}

/// Creates one collisionless active owner with a policy-allocated stable key.
@immutable
final class PrefabV3CreateOperation extends PrefabV3LifecycleOperation {
  PrefabV3CreateOperation({
    required this.id,
    required this.kind,
    required this.visualSource,
    required this.anchorXPx,
    required this.anchorYPx,
    Iterable<String> tags = const <String>[],
  }) : tags = List<String>.unmodifiable(tags);

  final String id;
  final PrefabKind kind;
  final PrefabVisualSource visualSource;
  final int anchorXPx;
  final int anchorYPx;
  final List<String> tags;
}

/// Copies one complete owner under a fresh key and revision 1.
@immutable
final class PrefabV3DuplicateOperation extends PrefabV3LifecycleOperation {
  const PrefabV3DuplicateOperation({
    required this.sourcePrefabKey,
    this.targetId,
  });

  final String sourcePrefabKey;
  final String? targetId;
}

/// Renames one owner while retaining its stable prefab key.
@immutable
final class PrefabV3RenameOperation extends PrefabV3LifecycleOperation {
  const PrefabV3RenameOperation({
    required this.prefabKey,
    required this.nextId,
  });

  final String prefabKey;
  final String nextId;
}

/// Removes one prefab owner from the staged catalog.
@immutable
final class PrefabV3DeleteOperation extends PrefabV3LifecycleOperation {
  const PrefabV3DeleteOperation({required this.prefabKey});

  final String prefabKey;
}

/// One stale-checked prefab-v3 lifecycle mutation.
@immutable
final class PrefabV3LifecycleCommit {
  const PrefabV3LifecycleCommit({
    required this.before,
    required this.operation,
  });

  final PrefabV3LifecycleSnapshot before;
  final PrefabV3LifecycleOperation operation;
}

/// Outcome of one prefab-v3 lifecycle mutation.
final class PrefabV3LifecycleCommitResult {
  PrefabV3LifecycleCommitResult({
    required this.document,
    required this.accepted,
    required this.changed,
    Iterable<PrefabValidationIssue> issues = const <PrefabValidationIssue>[],
  }) : issues = List<PrefabValidationIssue>.unmodifiable(issues);

  final PrefabV3StagingDocument document;
  final bool accepted;
  final bool changed;
  final List<PrefabValidationIssue> issues;
}

/// Deterministic identity, allocation, and revision policy for prefab v3.
final class PrefabV3LifecycleCommitPolicy {
  const PrefabV3LifecycleCommitPolicy();

  PrefabV3LifecycleCommitResult apply({
    required PrefabV3StagingDocument document,
    required PrefabV3LifecycleCommit commit,
  }) {
    if (PrefabV3LifecycleSnapshot.fromDocument(document) != commit.before) {
      return _rejected(
        document,
        code: 'prefab_v3_lifecycle_commit_stale',
        message:
            'Prefab ownership changed after this lifecycle edit began; '
            'reload the current source set before committing.',
      );
    }

    final candidate = switch (commit.operation) {
      final PrefabV3CreateOperation operation => _create(document, operation),
      final PrefabV3DuplicateOperation operation => _duplicate(
        document,
        operation,
      ),
      final PrefabV3RenameOperation operation => _rename(document, operation),
      final PrefabV3DeleteOperation operation => _delete(document, operation),
    };
    if (identical(candidate, document)) {
      return PrefabV3LifecycleCommitResult(
        document: document,
        accepted: true,
        changed: false,
      );
    }
    if (candidate is _LifecycleRejection) {
      return _rejected(
        document,
        code: candidate.code,
        message: candidate.message,
      );
    }

    final next = candidate as PrefabV3StagingDocument;
    final currentByKey = <String, PrefabV3Def>{
      for (final prefab in document.data.prefabs) prefab.prefabKey: prefab,
    };
    final affectedKeys = next.data.prefabs
        .where((prefab) => currentByKey[prefab.prefabKey] != prefab)
        .map((prefab) => prefab.prefabKey)
        .toSet();
    final ownerIssues = <PrefabValidationIssue>[];
    for (final prefab in next.data.prefabs) {
      if (!affectedKeys.contains(prefab.prefabKey)) continue;
      ownerIssues.addAll(
        validatePrefabV3Owner(
          prefabData: next.data,
          tileData: next.tileData,
          prefab: prefab,
          visualBounds: next.visualBoundsByPrefabKey[prefab.prefabKey],
        ),
      );
    }
    if (ownerIssues.any(
      (issue) => issue.severity == PrefabValidationSeverity.error,
    )) {
      return PrefabV3LifecycleCommitResult(
        document: document,
        accepted: false,
        changed: false,
        issues: ownerIssues,
      );
    }
    return PrefabV3LifecycleCommitResult(
      document: next,
      accepted: true,
      changed: true,
      issues: ownerIssues,
    );
  }

  Object _create(
    PrefabV3StagingDocument document,
    PrefabV3CreateOperation operation,
  ) {
    final idIssue = _idIssue(document, operation.id);
    if (idIssue != null) return idIssue;
    if (!_stringListsEqual(
      operation.tags,
      PrefabDeterminism.normalizeTags(operation.tags),
    )) {
      return const _LifecycleRejection(
        code: 'prefab_v3_lifecycle_tags_noncanonical',
        message:
            'New prefab tags must be trimmed, non-empty, unique, and ordered '
            'lexically.',
      );
    }
    final key = PrefabDeterminism.allocatePrefabKey(
      id: operation.id,
      usedPrefabKeys: document.data.prefabs
          .map((prefab) => prefab.prefabKey)
          .toSet(),
    );
    final prefab = PrefabV3Def(
      prefabKey: key,
      id: operation.id,
      revision: 1,
      status: PrefabStatus.active,
      kind: operation.kind,
      visualSource: operation.visualSource,
      anchorXPx: operation.anchorXPx,
      anchorYPx: operation.anchorYPx,
      collisionShapes: const [],
      tags: operation.tags,
    );
    return _replaceOwners(document, <PrefabV3Def>[
      ...document.data.prefabs,
      prefab,
    ], changedKey: key);
  }

  Object _duplicate(
    PrefabV3StagingDocument document,
    PrefabV3DuplicateOperation operation,
  ) {
    final source = document.data.prefabs
        .where((prefab) => prefab.prefabKey == operation.sourcePrefabKey)
        .firstOrNull;
    if (source == null) {
      return _LifecycleRejection(
        code: 'prefab_v3_duplicate_source_missing',
        message:
            'Cannot duplicate unknown prefab ${operation.sourcePrefabKey}.',
      );
    }
    final targetId = operation.targetId ?? _allocateCopyId(document, source.id);
    final idIssue = _idIssue(document, targetId);
    if (idIssue != null) return idIssue;
    final key = PrefabDeterminism.allocatePrefabKey(
      id: targetId,
      usedPrefabKeys: document.data.prefabs
          .map((prefab) => prefab.prefabKey)
          .toSet(),
    );
    final duplicate = source.copyWith(
      prefabKey: key,
      id: targetId,
      revision: 1,
      status: PrefabStatus.active,
    );
    return _replaceOwners(document, <PrefabV3Def>[
      ...document.data.prefabs,
      duplicate,
    ], changedKey: key);
  }

  Object _rename(
    PrefabV3StagingDocument document,
    PrefabV3RenameOperation operation,
  ) {
    final index = document.data.prefabs.indexWhere(
      (prefab) => prefab.prefabKey == operation.prefabKey,
    );
    if (index < 0) {
      return _LifecycleRejection(
        code: 'prefab_v3_rename_owner_missing',
        message: 'Cannot rename unknown prefab ${operation.prefabKey}.',
      );
    }
    final current = document.data.prefabs[index];
    if (current.id == operation.nextId) return document;
    final idIssue = _idIssue(
      document,
      operation.nextId,
      exceptPrefabKey: operation.prefabKey,
    );
    if (idIssue != null) return idIssue;
    final prefabs = document.data.prefabs.toList(growable: false);
    prefabs[index] = current.copyWith(
      id: operation.nextId,
      revision: current.revision + 1,
    );
    return _replaceOwners(document, prefabs, changedKey: operation.prefabKey);
  }

  Object _delete(
    PrefabV3StagingDocument document,
    PrefabV3DeleteOperation operation,
  ) {
    if (!document.data.prefabs.any(
      (prefab) => prefab.prefabKey == operation.prefabKey,
    )) {
      return _LifecycleRejection(
        code: 'prefab_v3_delete_owner_missing',
        message: 'Cannot delete unknown prefab ${operation.prefabKey}.',
      );
    }
    return _replaceOwners(
      document,
      document.data.prefabs.where(
        (prefab) => prefab.prefabKey != operation.prefabKey,
      ),
      changedKey: operation.prefabKey,
    );
  }

  PrefabV3StagingDocument _replaceOwners(
    PrefabV3StagingDocument document,
    Iterable<PrefabV3Def> prefabs, {
    required String changedKey,
  }) {
    final data = document.data.copyWith(
      prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(prefabs),
    );
    return document.copyWith(
      data: data,
      visualBoundsByPrefabKey: PrefabVisualBoundsResolver.resolveAll(
        prefabData: data,
        tileData: document.tileData,
      ),
      changedPrefabKeys: <String>{...document.changedPrefabKeys, changedKey},
    );
  }
}

_LifecycleRejection? _idIssue(
  PrefabV3StagingDocument document,
  String id, {
  String? exceptPrefabKey,
}) {
  if (id.isEmpty || id != id.trim()) {
    return const _LifecycleRejection(
      code: 'prefab_v3_lifecycle_id_invalid',
      message: 'Prefab id must be non-empty with no surrounding whitespace.',
    );
  }
  final normalized = id.toLowerCase();
  if (document.data.prefabs.any(
    (prefab) =>
        prefab.prefabKey != exceptPrefabKey &&
        prefab.id.toLowerCase() == normalized,
  )) {
    return _LifecycleRejection(
      code: 'prefab_v3_lifecycle_id_collision',
      message: 'Prefab id "$id" is already owned.',
    );
  }
  return null;
}

String _allocateCopyId(PrefabV3StagingDocument document, String sourceId) {
  final existingIds = document.data.prefabs
      .map((prefab) => prefab.id.toLowerCase())
      .toSet();
  final base = '${sourceId}_copy';
  if (!existingIds.contains(base.toLowerCase())) return base;
  var suffix = 2;
  while (existingIds.contains('${base}_$suffix'.toLowerCase())) {
    suffix += 1;
  }
  return '${base}_$suffix';
}

PrefabV3LifecycleCommitResult _rejected(
  PrefabV3StagingDocument document, {
  required String code,
  required String message,
}) => PrefabV3LifecycleCommitResult(
  document: document,
  accepted: false,
  changed: false,
  issues: <PrefabValidationIssue>[
    PrefabValidationIssue(
      code: code,
      message: message,
      sourcePath: 'assets/authoring/level/prefab_defs.json',
    ),
  ],
);

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _LifecycleRejection {
  const _LifecycleRejection({required this.code, required this.message});

  final String code;
  final String message;
}
