import 'package:flutter/material.dart';

import '../../../session/editor_session_controller.dart';
import '../../../terrain_authoring/polygon_authoring_migration_required.dart';

/// Read-only route shown when normal terrain source is not on polygon schemas.
///
/// It offers only a source recheck. Migration writes stay unavailable so this
/// view cannot mutate or partially upgrade authored source.
class PolygonAuthoringMigrationRequiredWorkspace extends StatelessWidget {
  const PolygonAuthoringMigrationRequiredWorkspace({
    super.key,
    required this.controller,
  });

  /// Read-only command displayed verbatim; it never authorizes source writes.
  static const String migrationCheckCommand =
      'dart run tool/migrate_polygon_authoring.dart --check '
      '--report=.tmp/slopes-phase4-migration.json';

  final EditorSessionController controller;

  /// Re-runs the active normal loader atomically so a malformed external edit
  /// cannot replace this fail-closed scene with legacy page chrome.
  static Future<void> recheckSource(EditorSessionController controller) async {
    final scene = controller.scene;
    if (scene is! PolygonAuthoringMigrationRequiredScene) return;
    await controller.loadWorkspaceForPlugin(
      pluginId: scene.domain.pluginId,
      loadDocument: (plugin, workspace) => plugin.loadFromRepo(workspace),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scene = controller.scene;
        if (scene is! PolygonAuthoringMigrationRequiredScene) {
          return const Center(child: CircularProgressIndicator());
        }
        final colorScheme = Theme.of(context).colorScheme;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                key: const ValueKey<String>(
                  'polygon_authoring_migration_required',
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.construction_outlined,
                            color: colorScheme.tertiary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${scene.domain.editorLabel} requires polygon source',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Detected: ${scene.detectedSourceLabel}'),
                      const SizedBox(height: 8),
                      Text('Required: ${scene.domain.requiredSourceLabel}'),
                      const SizedBox(height: 8),
                      Text('Source: ${scene.domain.sourceLocation}'),
                      const SizedBox(height: 20),
                      const Text(
                        'Legacy collision editing and export are disabled to '
                        'avoid maintaining rectangle and polygon terrain as '
                        'parallel authorities.',
                      ),
                      const SizedBox(height: 16),
                      const Text('Read-only readiness check:'),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: colorScheme.surfaceContainerHighest,
                        child: const SelectableText(migrationCheckCommand),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Migration --write and live polygon runtime authority '
                        'are not enabled yet.',
                      ),
                      if (controller.loadError != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          controller.loadError!,
                          key: const ValueKey<String>(
                            'polygon_migration_recheck_error',
                          ),
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'polygon_migration_recheck_source',
                        ),
                        onPressed:
                            controller.isLoading || controller.isExporting
                            ? null
                            : () async {
                                await recheckSource(controller);
                              },
                        icon: controller.isLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Recheck source'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
