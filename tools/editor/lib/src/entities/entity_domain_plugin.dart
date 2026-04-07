// Plugin-facing entrypoint for the entities authoring workflow.
//
// This file is the stable seam the session controller talks to. Parsing,
// in-memory document rules, and source-backed export live in separate
// collaborators so route wiring stays small and new contributors can find the
// real ownership boundaries quickly.
import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'entity_document_pipeline.dart';
import 'entity_domain_models.dart';
import 'entity_export_pipeline.dart';
import 'entity_source_parser.dart';

/// Plugin entry point for the entities authoring workflow.
///
/// This class intentionally stays small. Parsing, in-memory document behavior,
/// and source-backed export each live in their own collaborator so the route
/// pipeline is easier to evolve without turning the plugin into a second
/// all-knowing framework layer.
class EntityDomainPlugin implements AuthoringDomainPlugin {
  static const String pluginId = 'entities';

  /// Creates the plugin with injectable collaborators for focused tests.
  ///
  /// Production code uses the default parser/document/export pipeline split so
  /// route/session code does not take on source-editing responsibilities.
  factory EntityDomainPlugin({
    EntitySourceParser? parser,
    EntityDocumentPipeline? documentPipeline,
    EntityExportPipeline? exportPipeline,
  }) {
    final resolvedDocumentPipeline =
        documentPipeline ?? EntityDocumentPipeline();
    return EntityDomainPlugin._(
      parser: parser ?? EntitySourceParser(),
      documentPipeline: resolvedDocumentPipeline,
      exportPipeline:
          exportPipeline ??
          EntityExportPipeline(documentPipeline: resolvedDocumentPipeline),
    );
  }

  EntityDomainPlugin._({
    required EntitySourceParser parser,
    required EntityDocumentPipeline documentPipeline,
    required EntityExportPipeline exportPipeline,
  }) : _parser = parser,
       _documentPipeline = documentPipeline,
       _exportPipeline = exportPipeline;

  final EntitySourceParser _parser;
  final EntityDocumentPipeline _documentPipeline;
  final EntityExportPipeline _exportPipeline;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final parseResult = _parser.parse(workspace);
    final baseline = <String, EntityEntry>{
      for (final entry in parseResult.entries) entry.id: entry,
    };
    return EntityDocument(
      entries: parseResult.entries,
      baselineById: baseline,
      runtimeGridCellSize: parseResult.runtimeGridCellSize,
      loadIssues: parseResult.issues,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return _documentPipeline.validate(_asEntityDocument(document));
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    return _documentPipeline.buildScene(_asEntityDocument(document));
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    return _documentPipeline.applyEdit(_asEntityDocument(document), command);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final entityDocument = _asEntityDocument(document);
    final validationIssues = _documentPipeline.validate(entityDocument);
    return _exportPipeline.exportToRepo(
      workspace,
      document: entityDocument,
      validationIssues: validationIssues,
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    return _exportPipeline.describePendingChanges(
      workspace,
      document: _asEntityDocument(document),
    );
  }

  EntityDocument _asEntityDocument(AuthoringDocument document) {
    if (document is! EntityDocument) {
      throw StateError(
        'EntityDomainPlugin expected EntityDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }
}
