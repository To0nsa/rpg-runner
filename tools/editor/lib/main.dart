import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/app/runner_editor_app.dart';

void main(List<String> args) {
  final workspacePath = args.isEmpty ? _defaultWorkspacePath() : args.first;
  runEditorApp(initialWorkspacePath: workspacePath);
}

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
