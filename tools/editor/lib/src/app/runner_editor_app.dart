import 'package:flutter/material.dart';

import '../chunks/chunk_domain_plugin.dart';
import '../entities/entity_domain_plugin.dart';
import '../domain/authoring_plugin_registry.dart';
import '../prefabs/prefab_domain_plugin.dart';
import '../session/editor_session_controller.dart';
import 'pages/home/editor_home_page.dart';

void runEditorApp({required String initialWorkspacePath}) {
  final registry = AuthoringPluginRegistry(
    plugins: [EntityDomainPlugin(), PrefabDomainPlugin(), ChunkDomainPlugin()],
  );

  final controller = EditorSessionController(
    pluginRegistry: registry,
    initialPluginId: EntityDomainPlugin.pluginId,
    initialWorkspacePath: initialWorkspacePath,
  );

  runApp(RunnerEditorApp(controller: controller));
}

class RunnerEditorApp extends StatelessWidget {
  const RunnerEditorApp({super.key, required this.controller});

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
