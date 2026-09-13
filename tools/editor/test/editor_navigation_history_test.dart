import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/home/editor_navigation_history.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_navigation_state.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

class _Location extends EditorPageLocation {
  const _Location(this.owner);
  final String owner;
}

EditorNavigationLocation _visit(String route, String owner) =>
    EditorNavigationLocation(routeId: route, page: _Location(owner));

void main() {
  test(
    'restored polygon selections clear deleted shapes and stale indices',
    () {
      final shape = TerrainSourceShapeDef(
        shapeId: 'shape',
        vertices: const [
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 4, yHalfPixels: 0),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 4),
        ],
      );
      final selected = TerrainPolygonSelection.vertex('shape', 2);
      expect(selected.resolveAgainst([shape]), same(selected));
      expect(selected.resolveAgainst([]), isNull);
      expect(
        TerrainPolygonSelection.vertex('shape', 3).resolveAgainst([shape]),
        isNull,
      );
      expect(
        TerrainPolygonSelection.edge('missing', 0).resolveAgainst([shape]),
        isNull,
      );
    },
  );
  test(
    'visits retain independent owners; normal switching resumes last view',
    () {
      final chunkA = _visit('chunks', 'a');
      final prefab = _visit('prefabs', 'tree');
      final chunkB = _visit('chunks', 'b');
      final history = EditorNavigationHistory(chunkA);
      history.commit(origin: chunkA, destination: prefab);
      history.commit(origin: prefab, destination: chunkB);
      history.commit(origin: chunkB, destination: prefab, historyIndex: 1);
      expect(history.back?.page, same(chunkA.page));
      expect(history.forward?.page, same(chunkB.page));
      expect(history.forRoute('chunks').page, same(chunkB.page));
      history.commit(origin: prefab, destination: chunkA, historyIndex: 0);
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isTrue);
      expect(history.forRoute('chunks').page, same(chunkA.page));
    },
  );

  test(
    'reading destinations leaves history intact; new visits cut Forward',
    () {
      final a = _visit('chunks', 'a');
      final b = _visit('prefabs', 'b');
      final c = _visit('entities', 'c');
      final history = EditorNavigationHistory(a);
      history.commit(origin: a, destination: b);
      expect(history.back, same(a));
      history.forRoute('entities');
      expect(history.index, 1);
      expect(history.current, same(b));
      history.commit(origin: b, destination: a, historyIndex: 0);
      history.commit(origin: a, destination: c);
      expect(history.canGoForward, isFalse);
      expect(history.back, same(a));
      expect(history.forRoute('prefabs').page, same(b.page));
    },
  );

  test(
    'history is bounded and workspace reset clears all remembered owners',
    () {
      final history = EditorNavigationHistory(_visit('chunks', '0'));
      for (var i = 1; i < 150; i++) {
        history.commit(
          origin: history.current,
          destination: _visit('chunks', '$i'),
        );
      }
      expect(history.index, EditorNavigationHistory.maxVisits - 1);
      history.reset(const EditorNavigationLocation(routeId: 'entities'));
      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
      expect(history.forRoute('chunks').page, isNull);
    },
  );
}
