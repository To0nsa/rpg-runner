import 'package:flutter/material.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../entities/entity_domain_plugin.dart';
import '../domain/authoring_plugin_registry.dart';
import '../levels/level_domain_plugin.dart';
import '../parallax/parallax_domain_plugin.dart';
import '../prefabs/domain/prefab_domain_plugin.dart';
import '../session/editor_session_controller.dart';
import 'pages/home/editor_home_page.dart';

/// Boots the standalone editor with the current bounded set of authoring
/// domains.
///
/// Creates one plugin registry and one long-lived session controller for the
/// whole app so route switching stays inside a single coherent session model.
/// The initial workspace path only seeds controller context; each route still
/// loads its document explicitly through the active plugin.
void runEditorApp({required String initialWorkspacePath}) {
  final registry = AuthoringPluginRegistry(
    plugins: [
      EntityDomainPlugin(),
      PrefabDomainPlugin(),
      ChunkDomainPlugin(),
      LevelDomainPlugin(),
      ParallaxDomainPlugin(),
    ],
  );

  final controller = EditorSessionController(
    pluginRegistry: registry,
    initialPluginId: EntityDomainPlugin.pluginId,
    initialWorkspacePath: initialWorkspacePath,
  );

  runApp(RunnerEditorApp(controller: controller));
}

/// Root Flutter shell for the editor tool.
///
/// Keeps theming and top-level navigation separate from domain plugins. The
/// injected [controller] is shared across all routes so workspace selection,
/// undo/redo, pending changes, and export state remain session-coherent.
class RunnerEditorApp extends StatelessWidget {
  const RunnerEditorApp({super.key, required this.controller});

  /// Shared editor session used by the home page and all plugin-backed routes.
  final EditorSessionController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPG Runner Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF0EA5E9),
        ),
      ),
      home: EditorHomePage(controller: controller),
    );
  }
}
