import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';

/// Authoring domains that require the coordinated polygon-source migration.
enum PolygonAuthoringMigrationDomain {
  prefabs(
    pluginId: 'prefabs',
    editorLabel: 'Prefab Creator',
    legacySourceLabel: 'Prefab schema v1/v2 rectangle-collider source',
    requiredSourceLabel: 'Prefab schema v3 polygon source',
    sourceLocation: 'assets/authoring/level/prefab_defs.json',
  ),
  chunks(
    pluginId: 'chunks',
    editorLabel: 'Chunk Creator',
    legacySourceLabel: 'Chunk schema v1 ground-profile/gap source',
    requiredSourceLabel: 'Chunk schema v2 polygon source',
    sourceLocation: 'assets/authoring/level/chunks/*.json',
  );

  const PolygonAuthoringMigrationDomain({
    required this.pluginId,
    required this.editorLabel,
    required this.legacySourceLabel,
    required this.requiredSourceLabel,
    required this.sourceLocation,
  });

  final String pluginId;
  final String editorLabel;
  final String legacySourceLabel;
  final String requiredSourceLabel;
  final String sourceLocation;
}

/// Why a normal polygon authoring route cannot load an editable document.
enum PolygonAuthoringMigrationReason { legacySource, sourceMissing }

/// Fail-closed normal-loader result for source that is not yet current.
///
/// It intentionally contains no legacy editable data or write baseline. This
/// prevents session commands and export from retaining rectangle/ground-gap
/// authority while the one-time migration command is unavailable.
@immutable
final class PolygonAuthoringMigrationRequiredDocument
    extends AuthoringDocument {
  const PolygonAuthoringMigrationRequiredDocument({
    required this.domain,
    required this.reason,
  });

  final PolygonAuthoringMigrationDomain domain;
  final PolygonAuthoringMigrationReason reason;

  /// Human-readable source generation without implying missing means legacy.
  String get detectedSourceLabel => switch (reason) {
    PolygonAuthoringMigrationReason.legacySource => domain.legacySourceLabel,
    PolygonAuthoringMigrationReason.sourceMissing =>
      'No authoring source was found',
  };

  /// Stable blocking explanation shared by validation and failed export.
  String get message => switch (reason) {
    PolygonAuthoringMigrationReason.legacySource =>
      '${domain.editorLabel} detected ${domain.legacySourceLabel} and requires '
          '${domain.requiredSourceLabel}. Legacy editing is disabled.',
    PolygonAuthoringMigrationReason.sourceMissing =>
      '${domain.editorLabel} requires ${domain.requiredSourceLabel}, but '
          '${domain.sourceLocation} is missing. Legacy source initialization '
          'is disabled.',
  };

  /// Blocking issue exposed through the normal session validation envelope.
  ValidationIssue toValidationIssue() => ValidationIssue(
    severity: ValidationSeverity.error,
    code: 'polygon_authoring_migration_required',
    message: message,
    sourcePath: domain.sourceLocation,
  );

  /// Projects only migration facts; no legacy authoring model crosses to UI.
  PolygonAuthoringMigrationRequiredScene toScene() =>
      PolygonAuthoringMigrationRequiredScene(domain: domain, reason: reason);
}

/// UI projection for a blocked legacy or missing polygon source generation.
@immutable
final class PolygonAuthoringMigrationRequiredScene extends EditableScene {
  const PolygonAuthoringMigrationRequiredScene({
    required this.domain,
    required this.reason,
  });

  final PolygonAuthoringMigrationDomain domain;
  final PolygonAuthoringMigrationReason reason;

  /// Human-readable source generation rendered by the blocked workspace.
  String get detectedSourceLabel => switch (reason) {
    PolygonAuthoringMigrationReason.legacySource => domain.legacySourceLabel,
    PolygonAuthoringMigrationReason.sourceMissing =>
      'No authoring source was found',
  };
}
