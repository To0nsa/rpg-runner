import 'package:flutter/foundation.dart';

import '../workspace/editor_workspace.dart';

@immutable
class AuthoringCommand {
  const AuthoringCommand({
    required this.kind,
    this.payload = const <String, Object?>{},
  });

  final String kind;
  final Map<String, Object?> payload;
}

abstract class AuthoringDocument {
  const AuthoringDocument();
}

abstract class EditableScene {
  const EditableScene();
}

enum ValidationSeverity { info, warning, error }

@immutable
class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.sourcePath,
  });

  final ValidationSeverity severity;
  final String code;
  final String message;
  final String? sourcePath;
}

@immutable
class ExportArtifact {
  const ExportArtifact({required this.title, required this.content});

  final String title;
  final String content;
}

@immutable
class ExportResult {
  const ExportResult({
    required this.applied,
    this.artifacts = const <ExportArtifact>[],
  });

  final bool applied;
  final List<ExportArtifact> artifacts;
}

@immutable
class PendingFileDiff {
  const PendingFileDiff({
    required this.relativePath,
    required this.editCount,
    required this.unifiedDiff,
  });

  final String relativePath;
  final int editCount;
  final String unifiedDiff;
}

@immutable
class PendingChanges {
  const PendingChanges({
    this.changedEntryIds = const <String>[],
    this.fileDiffs = const <PendingFileDiff>[],
  });

  final List<String> changedEntryIds;
  final List<PendingFileDiff> fileDiffs;

  bool get hasChanges => changedEntryIds.isNotEmpty;
}

abstract class AuthoringDomainPlugin {
  String get id;
  String get displayName;

  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace);

  List<ValidationIssue> validate(AuthoringDocument document);

  EditableScene buildEditableScene(AuthoringDocument document);

  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  );

  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  });

  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  });
}
