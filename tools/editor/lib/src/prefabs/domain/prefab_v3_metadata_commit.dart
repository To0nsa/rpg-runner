import 'package:meta/meta.dart';

import '../models/models.dart';
import '../store/prefab_determinism.dart';
import '../validation/prefab_validation.dart';
import 'prefab_domain_models.dart';
import 'prefab_visual_bounds_resolver.dart';
import 'prefab_v3_owner_validation.dart';

/// Immutable revision-owned metadata for one existing prefab-v3 owner.
///
/// Stable identity, revision, and collision geometry are absent so this
/// contract cannot mutate them.
@immutable
final class PrefabV3MetadataSnapshot {
  PrefabV3MetadataSnapshot({
    required this.status,
    required this.kind,
    required this.visualSource,
    required this.anchorXPx,
    required this.anchorYPx,
    required Iterable<String> tags,
  }) : tags = List<String>.unmodifiable(tags);

  factory PrefabV3MetadataSnapshot.fromPrefab(PrefabV3Def prefab) =>
      PrefabV3MetadataSnapshot(
        status: prefab.status,
        kind: prefab.kind,
        visualSource: prefab.visualSource,
        anchorXPx: prefab.anchorXPx,
        anchorYPx: prefab.anchorYPx,
        tags: prefab.tags,
      );

  final PrefabStatus status;
  final PrefabKind kind;
  final PrefabVisualSource visualSource;
  final int anchorXPx;
  final int anchorYPx;
  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      other is PrefabV3MetadataSnapshot &&
      status == other.status &&
      kind == other.kind &&
      _visualSourcesEqual(visualSource, other.visualSource) &&
      anchorXPx == other.anchorXPx &&
      anchorYPx == other.anchorYPx &&
      _stringListsEqual(tags, other.tags);

  @override
  int get hashCode => Object.hash(
    status,
    kind,
    visualSource.type,
    visualSource.referenceId,
    anchorXPx,
    anchorYPx,
    Object.hashAll(tags),
  );
}

/// One optimistic-concurrency metadata edit for an existing prefab-v3 owner.
@immutable
final class PrefabV3MetadataCommit {
  const PrefabV3MetadataCommit({required this.before, required this.after});

  final PrefabV3MetadataSnapshot before;
  final PrefabV3MetadataSnapshot after;
}

/// Outcome of one prefab-v3 metadata commit.
final class PrefabV3MetadataCommitResult {
  PrefabV3MetadataCommitResult({
    required this.document,
    required this.accepted,
    required this.changed,
    Iterable<PrefabValidationIssue> issues = const <PrefabValidationIssue>[],
  }) : issues = List<PrefabValidationIssue>.unmodifiable(issues);

  final PrefabV3Document document;
  final bool accepted;
  final bool changed;
  final List<PrefabValidationIssue> issues;
}

/// Fail-closed metadata and revision policy for existing prefab-v3 owners.
final class PrefabV3MetadataCommitPolicy {
  const PrefabV3MetadataCommitPolicy();

  PrefabV3MetadataCommitResult apply({
    required PrefabV3Document document,
    required String prefabKey,
    required PrefabV3MetadataCommit commit,
  }) {
    final index = document.data.prefabs.indexWhere(
      (prefab) => prefab.prefabKey == prefabKey,
    );
    if (index < 0) {
      return _rejected(
        document,
        code: 'prefab_v3_metadata_owner_missing',
        message: 'Cannot edit unknown prefab $prefabKey.',
      );
    }
    final current = document.data.prefabs[index];
    if (PrefabV3MetadataSnapshot.fromPrefab(current) != commit.before) {
      return _rejected(
        document,
        code: 'prefab_v3_metadata_commit_stale',
        message:
            'Prefab ${current.id} changed after this metadata edit began; '
            'reload its current source before committing.',
      );
    }
    if (commit.before == commit.after) {
      return PrefabV3MetadataCommitResult(
        document: document,
        accepted: true,
        changed: false,
      );
    }
    if (!_stringListsEqual(
      commit.after.tags,
      PrefabDeterminism.normalizeTags(commit.after.tags),
    )) {
      return _rejected(
        document,
        code: 'prefab_v3_metadata_tags_noncanonical',
        message:
            'Prefab ${current.id} tags must be trimmed, non-empty, unique, '
            'and ordered lexically before commit.',
      );
    }

    final after = commit.after;
    final candidate = current.copyWith(
      revision: current.revision + 1,
      status: after.status,
      kind: after.kind,
      visualSource: after.visualSource,
      anchorXPx: after.anchorXPx,
      anchorYPx: after.anchorYPx,
      tags: after.tags,
    );
    final prefabs = document.data.prefabs.toList(growable: false);
    prefabs[index] = candidate;
    final data = document.data.copyWith(
      prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(prefabs),
    );
    final visualBounds = _resolveBounds(data, document.tileData);
    final issues = validatePrefabV3Owner(
      prefabData: data,
      tileData: document.tileData,
      prefab: candidate,
      visualBounds: visualBounds[prefabKey],
    );
    if (issues.any(
      (issue) => issue.severity == PrefabValidationSeverity.error,
    )) {
      return PrefabV3MetadataCommitResult(
        document: document,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }
    return PrefabV3MetadataCommitResult(
      document: document.copyWith(
        data: data,
        visualBoundsByPrefabKey: visualBounds,
        changedPrefabKeys: <String>{...document.changedPrefabKeys, prefabKey},
      ),
      accepted: true,
      changed: true,
      issues: issues,
    );
  }
}

PrefabV3MetadataCommitResult _rejected(
  PrefabV3Document document, {
  required String code,
  required String message,
}) => PrefabV3MetadataCommitResult(
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

Map<String, PrefabV3VisualBounds> _resolveBounds(
  PrefabV3FileData data,
  PrefabTileFileData tileData,
) {
  return PrefabVisualBoundsResolver.resolveAll(
    prefabData: data,
    tileData: tileData,
  );
}

bool _visualSourcesEqual(PrefabVisualSource left, PrefabVisualSource right) =>
    left.type == right.type && left.referenceId == right.referenceId;

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
