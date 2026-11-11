import 'dart:convert';
import 'dart:io';

import 'package:game_presentation/item_icon_ids.dart';
import 'package:runner_content_pipeline/item_source.dart';

import '../domain/authoring_types.dart';
import '../domain/authoring_session_semantics.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_write_transaction.dart';

const itemSourcePath = 'assets/authoring/items/item_defs.json';

/// One immutable item source plus the exact bytes the author loaded.
final class ItemDocument extends AuthoringDocument {
  ItemDocument(this.catalog, this.baseline, {String? selectedId})
    : selectedId = catalog.items.any((i) => i.id == selectedId)
          ? selectedId
          : catalog.items.firstOrNull?.id;
  final ItemCatalogSource catalog;
  final String baseline;
  final String? selectedId;
  ItemSource? get selected =>
      catalog.items.where((i) => i.id == selectedId).firstOrNull;
  ItemDocument withCatalog(ItemCatalogSource value, {String? selectedId}) =>
      ItemDocument(value, baseline, selectedId: selectedId ?? this.selectedId);
}

final class ItemScene extends EditableScene {
  const ItemScene(this.document);
  final ItemDocument document;
}

/// Owns identity allocation, compatible edits and source writes. There is no
/// delete/rename command. Build is a separate shell transaction.
final class ItemDomainPlugin
    implements
        AuthoringDomainPlugin,
        AuthoringSessionSemantics,
        AuthoringHistoryReconciliation {
  ItemDomainPlugin({this.verifyReplacements});

  /// Failure-injection seam also used to verify filesystem rollback in tests.
  final void Function()? verifyReplacements;
  static const pluginId = 'items';
  static const select = 'items_select',
      create = 'items_create',
      duplicate = 'items_duplicate',
      replace = 'items_replace';
  @override
  String get id => pluginId;
  @override
  Future<ItemDocument> loadFromRepo(EditorWorkspace workspace) async {
    final baseline = await File(workspace.resolve(itemSourcePath))
        .readAsString();
    final catalog = ItemCatalogSource.decode(baseline);
    catalog.validatePresentation(canonicalItemIconChoices);
    return ItemDocument(catalog, baseline);
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final doc = document as ItemDocument;
    try {
      doc.catalog.validatePresentation(canonicalItemIconChoices);
      doc.catalog.requireCompatibleWith(ItemCatalogSource.decode(doc.baseline));
      return [];
    } on FormatException catch (e) {
      return [
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'item_invalid',
          message: e.message,
          sourcePath: itemSourcePath,
        ),
      ];
    }
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      ItemScene(document as ItemDocument);

  /// A duplicate gets an unused ID even before persistence; ordinals append to
  /// the category's ABI, including reserved/internal projectile ordinals.
  static String allocateId(ItemCatalogSource catalog, String base) {
    final used = {
      ...catalog.items.map((i) => i.id),
      ...catalog.internalProjectiles.values,
      ...reservedItemIds,
    };
    final stem = base.length > 68 ? base.substring(0, 68) : base;
    var id = '${stem}Copy';
    for (var n = 2; used.contains(id); n++) {
      id = '${stem}Copy$n';
    }
    return id;
  }

  @override
  ItemDocument applyEdit(AuthoringDocument document, AuthoringCommand command) {
    final doc = document as ItemDocument;
    if (command.kind == select) {
      final id = command.payload['id'] as String;
      if (!doc.catalog.items.any((i) => i.id == id)) {
        throw ArgumentError('Unknown item $id.');
      }
      return id == doc.selectedId
          ? doc
          : doc.withCatalog(doc.catalog, selectedId: id);
    }
    final json = doc.catalog.toJson();
    final items = json['items'] as List;
    String? selected;
    if (command.kind == replace) {
      final id = command.payload['id'];
      final index = items.indexWhere((i) => i['id'] == id);
      if (index < 0 ||
          jsonEncode(command.payload['expected']) != jsonEncode(items[index])) {
        throw StateError('Item changed. Reload the form before applying.');
      }
      final value = ItemSource.decode(command.payload['item']);
      final old = doc.catalog.items[index];
      if (value.id != old.id ||
          value.category != old.category ||
          value.ordinal != old.ordinal) {
        throw const FormatException(
          'Existing item IDs/categories/ordinals are read-only.',
        );
      }
      items[index] = value.toJson();
    } else if (command.kind == create || command.kind == duplicate) {
      final category = ItemCategory.values.byName(
        command.payload['category'] as String,
      );
      final template = command.kind == duplicate
          ? doc.catalog.items.firstWhere(
              (i) => i.id == command.payload['templateId'],
            )
          : doc.catalog.items.firstWhere((i) => i.category == category);
      if (template.category != category) {
        throw const FormatException('Duplicate must retain its category.');
      }
      final ordinals = [
        for (final i in doc.catalog.items)
          if (i.category == category) i.ordinal,
        if (category == ItemCategory.projectile)
          ...doc.catalog.internalProjectiles.keys,
      ]..sort();
      final next = template.toJson();
      selected =
          (command.payload['newId'] as String?) ??
          allocateId(doc.catalog, template.id);
      next['id'] = selected;
      next['ordinal'] = ordinals.isEmpty ? 0 : ordinals.last + 1;
      next['name'] =
          command.payload['name'] ??
          {
            'en': _copyName(template.names['en']!, ' copy'),
            'fr': _copyName(template.names['fr']!, ' (copie)'),
          };
      // Creation starts with the selected category's valid baseline; all existing
      // fields are immediately editable through the same category controls.
      items.add(next);
    } else {
      throw ArgumentError('Unsupported item command: ${command.kind}');
    }
    json['items'] = items;
    final catalog = ItemCatalogSource.decode(jsonEncode(json));
    catalog.validatePresentation(canonicalItemIconChoices);
    catalog.requireCompatibleWith(ItemCatalogSource.decode(doc.baseline));
    if (catalog.encode() == doc.catalog.encode()) return doc;
    return doc.withCatalog(catalog, selectedId: selected);
  }

  static String _copyName(String name, String suffix) =>
      '${name.substring(0, name.length > 120 - suffix.length ? 120 - suffix.length : name.length)}$suffix';

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final doc = document as ItemDocument;
    final saved = ItemCatalogSource.decode(doc.baseline);
    final before = saved.encode(), after = doc.catalog.encode();
    if (before == after) return PendingChanges.empty;
    final old = {for (final i in saved.items) i.id: jsonEncode(i.toJson())};
    return PendingChanges(
      changedItemIds: [
        for (final i in doc.catalog.items)
          if (old[i.id] != jsonEncode(i.toJson())) i.id,
      ],
      fileDiffs: [
        PendingFileDiff(
          relativePath: itemSourcePath,
          editCount: 1,
          unifiedDiff:
              '--- a/$itemSourcePath\n+++ b/$itemSourcePath\n${before.split('\n').map((l) => '-$l').join('\n')}\n${after.split('\n').map((l) => '+$l').join('\n')}',
        ),
      ],
    );
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final doc = document as ItemDocument;
    final issues = validate(doc);
    if (issues.isNotEmpty) {
      return ExportResult(
        applied: false,
        outcome: ExportOutcome.validationFailed,
        message: issues.first.message,
      );
    }
    if (!describePendingChanges(workspace, document: doc).hasChanges) {
      return ExportResult(applied: false);
    }
    void guard() {
      final file = File(workspace.resolve(itemSourcePath));
      if (!file.existsSync() || file.readAsStringSync() != doc.baseline) {
        throw AuthoringSourceDrift(
          '$itemSourcePath changed. Reload before saving; your draft has been retained.',
        );
      }
    }

    try {
      guard();
      WorkspaceWriteTransaction([
        WorkspaceWriteArtifact(
          path: workspace.resolve(itemSourcePath),
          contents: doc.catalog.encode(),
        ),
      ]).apply(beforeReplace: guard, verifyReplacements: verifyReplacements);
      return ExportResult(applied: true);
    } on AuthoringSourceDrift catch (e) {
      return e.exportResult;
    } on WorkspaceWriteTransactionException catch (e) {
      return ExportResult(
        applied: e.outputsCommitted,
        outcome: e.outputsCommitted
            ? ExportOutcome.appliedWithCleanupRequired
            : e.rollbackFailures.isNotEmpty
            ? ExportOutcome.rollbackIncomplete
            : e.cause is AuthoringSourceDrift
            ? ExportOutcome.sourceDrift
            : ExportOutcome.failed,
        message: '$e',
        recovery: e.recovery == null ? null : _ItemRecovery(e.recovery!),
      );
    }
  }

  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      command.kind == select;
  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) => (restored as ItemDocument).withCatalog(
    restored.catalog,
    selectedId: (current as ItemDocument).selectedId,
  );
  @override
  AuthoringDocument? restoreContent({
    required AuthoringDocument current,
    required AuthoringDocument historical,
  }) {
    final now = current as ItemDocument, old = historical as ItemDocument;
    try {
      old.catalog.requireCompatibleWith(ItemCatalogSource.decode(now.baseline));
      return now.withCatalog(old.catalog);
    } on FormatException {
      // Undo must never erase/recycle a persisted identity that can own rewards.
      return null;
    }
  }
}

final class _ItemRecovery implements AuthoringExportRecovery {
  const _ItemRecovery(this.transaction);
  final WorkspaceWriteRecovery transaction;
  @override
  Future<ExportResult> retry() async {
    transaction.retry();
    return ExportResult(
      applied: transaction.outputsCommitted,
      outcome: transaction.outputsCommitted
          ? ExportOutcome.applied
          : ExportOutcome.failed,
      message: transaction.outputsCommitted
          ? null
          : 'Save was rolled back; review and retry.',
    );
  }
}
