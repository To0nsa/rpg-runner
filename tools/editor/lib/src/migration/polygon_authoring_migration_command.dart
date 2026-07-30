import 'dart:io';

import 'package:path/path.dart' as p;

import '../chunks/chunk_store.dart';
import '../prefabs/store/prefab_store.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'polygon_authoring_migration_check.dart';
import 'polygon_authoring_migration_plan.dart';

/// Read-only command adapter for polygon migration readiness checks.
///
/// Exit `0` means a complete blocker-free check, `1` means source/planning/
/// target validation failed, and `64` means invalid command usage. The only
/// optional write is the explicitly requested report artifact; authored source
/// and staged target contents are never written.
abstract final class PolygonAuthoringMigrationCommand {
  static const int successExitCode = 0;
  static const int blockedExitCode = 1;
  static const int usageExitCode = 64;

  /// Runs one command against [defaultWorkspaceRoot] or the current directory.
  ///
  /// Output sinks are injectable so argument, exit-code, and no-write behavior
  /// can be tested without spawning a process.
  static int run(
    List<String> arguments, {
    String? defaultWorkspaceRoot,
    StringSink? output,
    StringSink? errorOutput,
  }) {
    final stdoutSink = output ?? stdout;
    final stderrSink = errorOutput ?? stderr;
    final parsed = _parseArguments(arguments);
    if (parsed.helpRequested) {
      _writeUsage(stdoutSink);
      return successExitCode;
    }
    if (parsed.error case final message?) {
      stderrSink.writeln(message);
      _writeUsage(stderrSink);
      return usageExitCode;
    }

    final workspaceRoot =
        parsed.workspaceRoot ?? defaultWorkspaceRoot ?? _defaultWorkspaceRoot();
    final workspace = EditorWorkspace(rootPath: workspaceRoot);
    final String? reportPath;
    try {
      reportPath = parsed.reportPath == null
          ? null
          : _validatedReportPath(workspace, parsed.reportPath!);
    } on ArgumentError catch (error) {
      stderrSink.writeln('Invalid --report path: ${error.message}');
      return usageExitCode;
    }

    final PolygonAuthoringMigrationCheck check;
    try {
      check = PolygonAuthoringMigrationCheck.fromRepository(workspace.rootPath);
    } on PolygonAuthoringMigrationCheckException catch (error) {
      stderrSink.writeln(
        '[ERROR] ${error.code} ${error.sourcePath}: ${error.message}',
      );
      stderrSink.writeln('Migration check could not build a complete result.');
      return blockedExitCode;
    } on Object catch (error) {
      stderrSink.writeln('Migration check failed unexpectedly: $error');
      return blockedExitCode;
    }

    final driftIssues = _auditCurrentSources(workspace, check);
    if (driftIssues.isNotEmpty) {
      for (final issue in driftIssues) {
        stderrSink.writeln(
          '[ERROR] ${issue.code} ${issue.sourcePath}: ${issue.message}',
        );
      }
      stderrSink.writeln(
        'Migration check aborted after ${driftIssues.length} source drift '
        'issue(s).',
      );
      return blockedExitCode;
    }

    if (reportPath != null) {
      try {
        WorkspaceFileIo.atomicWrite(File(reportPath), check.toCanonicalJson());
      } on Object catch (error) {
        stderrSink.writeln('Unable to write migration report: $error');
        return blockedExitCode;
      }
      stdoutSink.writeln(
        'Wrote migration check report to '
        '${WorkspaceFileIo.toWorkspaceRelativePath(workspace, reportPath)}.',
      );
    }

    if (check.hasBlockers) {
      for (final issue in check.issues) {
        stderrSink.writeln(
          '[ERROR] ${issue.code} ${issue.sourcePath}: ${issue.message}',
        );
      }
      stderrSink.writeln(
        'Migration check blocked with ${check.issues.length} issue(s).',
      );
      return blockedExitCode;
    }

    stdoutSink.writeln(
      'Polygon migration check ready (${check.sourceState.jsonValue}): '
      '${check.summary.prefabCount} prefab(s), '
      '${check.summary.chunkCount} chunk(s), '
      '${check.targetFiles.length} validated target file(s).',
    );
    stdoutSink.writeln(
      '${check.targetFiles.where((target) => target.hasPendingChange).length} '
      'source file(s) have a pending representation migration.',
    );
    stdoutSink.writeln('No authored source was written.');
    return successExitCode;
  }
}

List<PolygonAuthoringMigrationIssue> _auditCurrentSources(
  EditorWorkspace workspace,
  PolygonAuthoringMigrationCheck check,
) {
  final current = <String, String>{};
  for (final source in check.sourceFiles) {
    final file = File(workspace.resolve(p.normalize(source.sourcePath)));
    if (!file.existsSync()) continue;
    try {
      current[source.sourcePath] = WorkspaceFileIo.sha256Digest(
        file.readAsStringSync(),
      );
    } on Object {
      // An unreadable file remains absent so the shared audit fails closed.
    }
  }
  return check.auditSourceDigests(current);
}

String _validatedReportPath(EditorWorkspace workspace, String rawPath) {
  if (rawPath.isEmpty) {
    throw ArgumentError.value(rawPath, '--report', 'Path must not be empty.');
  }
  final normalized = p.normalize(rawPath);
  if (p.isAbsolute(normalized)) {
    throw ArgumentError.value(
      rawPath,
      '--report',
      'Path must be workspace-relative.',
    );
  }
  if (p.extension(normalized).toLowerCase() != '.json') {
    throw ArgumentError.value(rawPath, '--report', 'Path must end in .json.');
  }
  final resolved = workspace.resolve(normalized);
  final authoringRoot = workspace.resolve('assets/authoring');
  if (resolved == authoringRoot || p.isWithin(authoringRoot, resolved)) {
    throw ArgumentError.value(
      rawPath,
      '--report',
      'Reports cannot be written inside authored source.',
    );
  }
  final forbiddenSources = <String>{
    workspace.resolve(PrefabStore.prefabDefsPath),
    workspace.resolve(ChunkStore.chunksDirectoryPath),
  };
  if (forbiddenSources.contains(resolved)) {
    throw ArgumentError.value(
      rawPath,
      '--report',
      'Report path conflicts with migration source.',
    );
  }
  return resolved;
}

_MigrationCommandArguments _parseArguments(List<String> arguments) {
  if (arguments.contains('-h') || arguments.contains('--help')) {
    return const _MigrationCommandArguments(helpRequested: true);
  }
  String? reportPath;
  String? workspaceRoot;
  var checkSeen = false;
  for (final argument in arguments) {
    if (argument == '--check') {
      if (checkSeen) {
        return const _MigrationCommandArguments(
          error: 'Duplicate argument: --check',
        );
      }
      checkSeen = true;
    } else if (argument == '--write') {
      return const _MigrationCommandArguments(
        error:
            '--write is not enabled; the migration transaction gate is still pending.',
      );
    } else if (argument.startsWith('--report=')) {
      if (reportPath != null) {
        return const _MigrationCommandArguments(
          error: 'Duplicate argument: --report',
        );
      }
      reportPath = argument.substring('--report='.length);
    } else if (argument.startsWith('--repo-root=')) {
      if (workspaceRoot != null) {
        return const _MigrationCommandArguments(
          error: 'Duplicate argument: --repo-root',
        );
      }
      workspaceRoot = argument.substring('--repo-root='.length);
      if (workspaceRoot.isEmpty) {
        return const _MigrationCommandArguments(
          error: '--repo-root must not be empty.',
        );
      }
    } else {
      return _MigrationCommandArguments(error: 'Unknown argument: $argument');
    }
  }
  return _MigrationCommandArguments(
    reportPath: reportPath,
    workspaceRoot: workspaceRoot,
  );
}

String _defaultWorkspaceRoot() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}

void _writeUsage(StringSink sink) {
  sink.writeln('Usage:');
  sink.writeln(
    '  dart run tool/migrate_polygon_authoring.dart '
    '[--check] [--report=<path.json>] [--repo-root=<path>]',
  );
  sink.writeln('');
  sink.writeln('No mode defaults to read-only --check.');
  sink.writeln('--write is intentionally unavailable in this phase.');
}

final class _MigrationCommandArguments {
  const _MigrationCommandArguments({
    this.helpRequested = false,
    this.error,
    this.reportPath,
    this.workspaceRoot,
  });

  final bool helpRequested;
  final String? error;
  final String? reportPath;
  final String? workspaceRoot;
}
