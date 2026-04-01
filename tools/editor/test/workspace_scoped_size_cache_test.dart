import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/workspace_scoped_size_cache.dart';

void main() {
  test('keeps entries when workspace path is unchanged', () {
    final cache = WorkspaceScopedSizeCache();

    cache.ensureWorkspace(r'C:\dev\rpg_runner');
    cache['assets/images/level/props/TX Village Props.png'] = const Size(
      256,
      256,
    );

    cache.ensureWorkspace(r'C:\dev\rpg_runner');
    expect(
      cache['assets/images/level/props/TX Village Props.png'],
      const Size(256, 256),
    );
  });

  test('clears entries when workspace path changes', () {
    final cache = WorkspaceScopedSizeCache();

    cache.ensureWorkspace(r'C:\dev\rpg_runner');
    cache['assets/images/level/props/TX Village Props.png'] = const Size(
      256,
      256,
    );

    cache.ensureWorkspace(r'C:\dev\other_project');
    expect(cache['assets/images/level/props/TX Village Props.png'], isNull);
  });

  test('normalizes workspace path before comparing scope', () {
    final cache = WorkspaceScopedSizeCache();

    cache.ensureWorkspace('C:\\dev\\rpg_runner\\.\\');
    cache['assets/images/level/tileset/TX Tileset Ground.png'] = const Size(
      64,
      64,
    );

    cache.ensureWorkspace(r'C:\dev\rpg_runner');
    expect(
      cache['assets/images/level/tileset/TX Tileset Ground.png'],
      const Size(64, 64),
    );
  });
}
