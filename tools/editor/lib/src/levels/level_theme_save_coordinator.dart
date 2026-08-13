import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../parallax/parallax_domain_models.dart';
import '../parallax/parallax_store.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_write_transaction.dart';
import 'level_domain_models.dart';
import 'level_store.dart';
import 'level_validation.dart';

typedef LevelThemeTransactionRunner =
    void Function(
      Iterable<WorkspaceWriteArtifact> artifacts, {
      required void Function() beforeReplace,
      required void Function() verifyReplacements,
    });

/// Deterministic Level/Parallax source plan presented and applied as one unit.
final class LevelThemeSavePlan {
  const LevelThemeSavePlan({
    required this.changedItemIds,
    required this.writes,
  });

  final List<String> changedItemIds;
  final List<LevelThemeFileWrite> writes;

  bool get hasChanges => writes.isNotEmpty;
}

/// One exact source replacement in a [LevelThemeSavePlan].
final class LevelThemeFileWrite {
  const LevelThemeFileWrite({
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}

/// Successful compound apply, optionally requiring transaction-file cleanup.
final class LevelThemeApplyResult {
  const LevelThemeApplyResult({this.cleanupRequiredPaths = const <String>[]});

  final List<String> cleanupRequiredPaths;

  bool get cleanupRequired => cleanupRequiredPaths.isNotEmpty;
}

/// Failure from a Level/theme source transaction before a complete commit.
final class LevelThemeSaveException implements Exception {
  const LevelThemeSaveException({
    required this.message,
    required this.cause,
    required this.rollbackComplete,
    required this.recoveryPaths,
  });

  final String message;
  final Object cause;
  final bool rollbackComplete;
  final List<String> recoveryPaths;

  @override
  String toString() => '$message Cause: $cause';
}

/// Composes Level and Parallax store plans without duplicating either codec.
final class LevelThemeSaveCoordinator {
  const LevelThemeSaveCoordinator({
    LevelStore levelStore = const LevelStore(),
    ParallaxStore parallaxStore = const ParallaxStore(),
    LevelThemeTransactionRunner transactionRunner =
        _runWorkspaceWriteTransaction,
  }) : _levelStore = levelStore,
       _parallaxStore = parallaxStore,
       _transactionRunner = transactionRunner;

  final LevelStore _levelStore;
  final ParallaxStore _parallaxStore;
  final LevelThemeTransactionRunner _transactionRunner;

  LevelThemeSavePlan buildSavePlan(
    EditorWorkspace workspace, {
    required LevelDefsDocument document,
  }) {
    final parallaxDocument = document.parallaxDocument;
    if (parallaxDocument == null) {
      throw StateError(
        'Level workflow has no typed Parallax source snapshot. Reload before '
        'planning or export.',
      );
    }
    final levelPlan = _levelStore.buildSavePlan(workspace, document: document);
    final parallaxPlan = _parallaxStore.buildSavePlan(
      workspace,
      document: parallaxDocument,
    );
    final changedItemIds = <String>[
      ...levelPlan.changedLevelIds.map((id) => 'level:$id'),
      ...parallaxPlan.changedParallaxThemeIds.map((id) => 'parallaxTheme:$id'),
    ]..sort();
    final writes = <LevelThemeFileWrite>[
      for (final write in levelPlan.writes)
        LevelThemeFileWrite(
          relativePath: write.relativePath,
          beforeContent: write.beforeContent,
          afterContent: write.afterContent,
        ),
      for (final write in parallaxPlan.writes)
        LevelThemeFileWrite(
          relativePath: write.relativePath,
          beforeContent: write.beforeContent,
          afterContent: write.afterContent,
        ),
    ]..sort((left, right) => left.relativePath.compareTo(right.relativePath));
    return LevelThemeSavePlan(
      changedItemIds: List<String>.unmodifiable(changedItemIds),
      writes: List<LevelThemeFileWrite>.unmodifiable(writes),
    );
  }

  LevelThemeApplyResult apply(
    EditorWorkspace workspace, {
    required LevelDefsDocument document,
    required LevelThemeSavePlan savePlan,
  }) {
    final blockingIssues = validateLevelDocument(
      document,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot apply an invalid Level/theme candidate: '
        '${blockingIssues.map((issue) => issue.code).join(', ')}.',
      );
    }
    final rebuilt = buildSavePlan(workspace, document: document);
    if (!_plansEqual(savePlan, rebuilt)) {
      throw StateError(
        'Level/theme save plan changed after confirmation. Review the pending '
        'diff and apply again.',
      );
    }
    if (!savePlan.hasChanges) return const LevelThemeApplyResult();

    final parallaxDocument = document.parallaxDocument!;
    final artifacts = savePlan.writes.map(
      (write) => WorkspaceWriteArtifact(
        path: workspace.resolve(write.relativePath),
        contents: write.afterContent,
      ),
    );
    try {
      _transactionRunner(
        artifacts,
        beforeReplace: () {
          _levelStore.verifySourceBaseline(workspace, document: document);
          _parallaxStore.verifySourceBaseline(
            workspace,
            document: parallaxDocument,
          );
        },
        verifyReplacements: () => _requireInstalledCandidate(
          workspace,
          savePlan: savePlan,
          document: document,
          levelStore: _levelStore,
          parallaxStore: _parallaxStore,
        ),
      );
      return const LevelThemeApplyResult();
    } on WorkspaceWriteTransactionException catch (error, stackTrace) {
      if (error.outputsCommitted) {
        _requireInstalledCandidate(
          workspace,
          savePlan: savePlan,
          document: document,
          levelStore: _levelStore,
          parallaxStore: _parallaxStore,
        );
        return LevelThemeApplyResult(
          cleanupRequiredPaths: _validateRecoveryPaths(
            workspace,
            savePlan: savePlan,
            recoveryPaths: error.recoveryPaths,
          ),
        );
      }
      Error.throwWithStackTrace(
        LevelThemeSaveException(
          message:
              'The Level/theme source transaction failed and attempted '
              'recovery.',
          cause: error.cause,
          rollbackComplete: error.rollbackComplete,
          recoveryPaths: error.recoveryPaths,
        ),
        stackTrace,
      );
    }
  }
}

void _runWorkspaceWriteTransaction(
  Iterable<WorkspaceWriteArtifact> artifacts, {
  required void Function() beforeReplace,
  required void Function() verifyReplacements,
}) {
  WorkspaceWriteTransaction(
    artifacts,
  ).apply(beforeReplace: beforeReplace, verifyReplacements: verifyReplacements);
}

void _requireInstalledCandidate(
  EditorWorkspace workspace, {
  required LevelThemeSavePlan savePlan,
  required LevelDefsDocument document,
  required LevelStore levelStore,
  required ParallaxStore parallaxStore,
}) {
  for (final write in savePlan.writes) {
    final file = File(workspace.resolve(write.relativePath));
    if (!file.existsSync() || file.readAsStringSync() != write.afterContent) {
      throw StateError(
        'Installed Level/theme source differs from the confirmed plan at '
        '${write.relativePath}.',
      );
    }
  }

  final levelRaw = File(
    workspace.resolve(LevelStore.defsPath),
  ).readAsStringSync();
  final parallaxRaw = File(
    workspace.resolve(ParallaxStore.defsPath),
  ).readAsStringSync();
  final installedLevels = levelStore.parseCanonicalSource(levelRaw);
  final installedThemes = parallaxStore.parseCanonicalSource(parallaxRaw);
  if (!_levelListsEqual(installedLevels, document.levels) ||
      !_themeListsEqual(installedThemes, document.parallaxDocument!.themes)) {
    throw StateError(
      'Installed Level/theme sources do not match the validated candidate.',
    );
  }
  final installedThemeIdSet = installedThemes
      .map((theme) => theme.parallaxThemeId)
      .toSet();
  for (final level in installedLevels) {
    if (!installedThemeIdSet.contains(level.visualThemeId)) {
      throw StateError(
        'Installed level "${level.levelId}" references missing visual theme '
        '"${level.visualThemeId}".',
      );
    }
  }
  final installedThemeIds =
      installedThemes
          .map((theme) => theme.parallaxThemeId)
          .toList(growable: false)
        ..sort();
  final levelIds =
      installedLevels.map((level) => level.levelId).toList(growable: false)
        ..sort();
  final installedDocument = document.copyWith(
    levels: installedLevels,
    availableParallaxVisualThemeIds: installedThemeIds,
    parallaxDocument: document.parallaxDocument!.copyWith(
      themes: installedThemes,
      availableLevelIds: levelIds,
      parallaxThemeIdByLevelId: <String, String>{
        for (final level in installedLevels) level.levelId: level.visualThemeId,
      },
    ),
  );
  final installedIssues = validateLevelDocument(
    installedDocument,
  ).where((issue) => issue.severity == ValidationSeverity.error).toList();
  if (installedIssues.isNotEmpty) {
    throw StateError(
      'Installed Level/theme source failed validation: '
      '${installedIssues.map((issue) => issue.code).join(', ')}.',
    );
  }
}

List<String> _validateRecoveryPaths(
  EditorWorkspace workspace, {
  required LevelThemeSavePlan savePlan,
  required List<String> recoveryPaths,
}) {
  final targetPrefixes = <String>[
    for (final write in savePlan.writes)
      '${_canonicalPath(workspace.resolve(write.relativePath))}.authoring-',
  ];
  final validated = <String>[];
  for (final path in recoveryPaths) {
    final canonical = _canonicalPath(path);
    final hasExpectedSuffix =
        canonical.endsWith('.tmp') || canonical.endsWith('.bak');
    if (!hasExpectedSuffix ||
        !targetPrefixes.any((prefix) => canonical.startsWith(prefix))) {
      throw StateError(
        'Transaction reported an unsafe recovery path outside its planned '
        'Level/theme siblings: $path',
      );
    }
    validated.add(p.normalize(File(path).absolute.path));
  }
  validated.sort();
  return List<String>.unmodifiable(validated);
}

String _canonicalPath(String path) {
  final normalized = p
      .normalize(File(path).absolute.path)
      .replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _levelListsEqual(List<LevelDef> left, List<LevelDef> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!levelDefEquals(left[index], right[index])) return false;
  }
  return true;
}

bool _themeListsEqual(
  List<ParallaxThemeDef> left,
  List<ParallaxThemeDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!parallaxThemeEquals(left[index], right[index])) return false;
  }
  return true;
}

bool _plansEqual(LevelThemeSavePlan left, LevelThemeSavePlan right) {
  if (left.changedItemIds.length != right.changedItemIds.length ||
      left.writes.length != right.writes.length) {
    return false;
  }
  for (var index = 0; index < left.changedItemIds.length; index += 1) {
    if (left.changedItemIds[index] != right.changedItemIds[index]) return false;
  }
  for (var index = 0; index < left.writes.length; index += 1) {
    final a = left.writes[index];
    final b = right.writes[index];
    if (a.relativePath != b.relativePath ||
        a.beforeContent != b.beforeContent ||
        a.afterContent != b.afterContent) {
      return false;
    }
  }
  return true;
}
