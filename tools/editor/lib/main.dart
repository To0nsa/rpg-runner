import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/app/runner_editor_app.dart';

/// Launch with `flutter run -d windows` in tools/editor directory
void main() {
  final workspacePath = _defaultWorkspacePath();
  runEditorApp(initialWorkspacePath: workspacePath);
}

/// Select rpg_runner root as workspace 
String _defaultWorkspacePath() {
  final cwd = Directory.current.path;
  final normalizedCwd = p.normalize(cwd);
  final baseName = p.basename(normalizedCwd).toLowerCase();
  final parentName = p.basename(p.dirname(normalizedCwd)).toLowerCase();

  if (baseName == 'editor' && parentName == 'tools') {
    return p.normalize(p.join(normalizedCwd, '..', '..'));
  }
  return normalizedCwd;
}
