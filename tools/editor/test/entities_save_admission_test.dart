import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/entities/entities_editor_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_document_pipeline.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/entity_test_support.dart';

void main() {
  for (final raw in ['NaN', 'Infinity']) {
    testWidgets('Save retains non-finite entity input $raw without dispatch', (
      tester,
    ) async {
      final pipeline = _TrackingEntityPipeline();
      final session = await _mount(tester, pipeline: pipeline);
      final before = session.document;
      await tester.enterText(_halfX, raw);
      await tester.pump();
      final state = tester.state(find.byType(EntitiesEditorPage));
      final outcome = await (state as EditorPageSaveHandler).saveEditorPage();
      expect(outcome, EditorPageSaveResult.blocked);
      expect(pipeline.calls, 0);
      expect(session.document, same(before));
      expect(_text(tester), raw);
      expect((state as EditorPageLocalDraftState).hasLocalDraftChanges, isTrue);
      expect(session.canUndo, isFalse);
      expect(session.lastExportResult, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  for (final throwsOnApply in [false, true]) {
    testWidgets(
      'rejected entity Save preserves exact draft: throws=$throwsOnApply',
      (tester) async {
        final session = await _mount(
          tester,
          pipeline: _TrackingEntityPipeline(
            reject: true,
            throwsOnApply: throwsOnApply,
          ),
        );
        final before = session.document;
        await tester.enterText(_halfX, '12.5000');
        await tester.pump();
        final state = tester.state(find.byType(EntitiesEditorPage));
        expect(
          await (state as EditorPageSaveHandler).saveEditorPage(),
          EditorPageSaveResult.blocked,
        );
        expect(session.document, same(before));
        expect(_text(tester), '12.5000');
        expect(
          (state as EditorPageLocalDraftState).hasLocalDraftChanges,
          isTrue,
        );
        expect(session.canUndo, isFalse);
        expect(session.lastExportResult, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'equivalent numeric input normalizes as no changes without export',
    (tester) async {
      final session = await _mount(tester);
      await tester.enterText(_halfX, '11');
      await tester.pump();
      final state = tester.state(find.byType(EntitiesEditorPage));
      expect(
        await (state as EditorPageSaveHandler).saveEditorPage(),
        EditorPageSaveResult.noChanges,
      );
      expect(_text(tester), '11.00');
      expect(
        (state as EditorPageLocalDraftState).hasLocalDraftChanges,
        isFalse,
      );
      expect(session.lastExportResult, isNull);
      expect(session.canUndo, isFalse);
    },
  );

  testWidgets(
    'Save includes focused valid entity values and refreshes canonical source',
    (tester) async {
      final session = await _mount(tester);
      await tester.enterText(_halfX, '12.5');
      await tester.pump();
      final state = tester.state(find.byType(EntitiesEditorPage));
      final result = await tester.runAsync(
        () => (state as EditorPageSaveHandler).saveEditorPage(),
      );
      await tester.pump();
      expect(result, EditorPageSaveResult.saved);
      expect(session.exportError, isNull);
      expect(_text(tester), '12.50');
      expect(
        (state as EditorPageLocalDraftState).hasLocalDraftChanges,
        isFalse,
      );
      expect(session.pendingChanges.hasChanges, isFalse);
      final entry = (session.document! as EntityDocument).entries.singleWhere(
        (entry) => entry.id == 'player.eloise',
      );
      expect(entry.halfX, 12.5);
      expect(tester.takeException(), isNull);
    },
  );
}

final _halfX = find.widgetWithText(TextField, 'halfX');
String _text(WidgetTester tester) =>
    tester.widget<TextField>(_halfX).controller!.text;

Future<EditorSessionController> _mount(
  WidgetTester tester, {
  EntityDocumentPipeline? pipeline,
}) async {
  final fixture = Directory.systemTemp.createTempSync(
    'entities_save_admission_',
  );
  addTearDown(() => fixture.deleteSync(recursive: true));
  writeEntityColliderFixture(fixture.path);
  final plugin = EntityDomainPlugin(documentPipeline: pipeline);
  final session = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
    initialPluginId: plugin.id,
    initialWorkspacePath: fixture.path,
  );
  addTearDown(session.dispose);
  await tester.runAsync(session.loadWorkspace);
  expect(session.loadError, isNull);
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: EntitiesEditorPage(controller: session)),
    ),
  );
  await tester.pump();
  return session;
}

class _TrackingEntityPipeline extends EntityDocumentPipeline {
  _TrackingEntityPipeline({this.reject = false, this.throwsOnApply = false});
  final bool reject;
  final bool throwsOnApply;
  int calls = 0;

  @override
  EntityDocument applyEdit(EntityDocument document, AuthoringCommand command) {
    calls++;
    if (throwsOnApply) {
      throw ArgumentError('Source target no longer accepts the edit.');
    }
    return reject ? document : super.applyEdit(document, command);
  }
}
