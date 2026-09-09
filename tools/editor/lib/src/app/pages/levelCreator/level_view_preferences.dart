import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'level_creator_navigation.dart';

/// Optional convenience state outside the repository. It never contains source
/// edits, history, captures, or asset paths, and malformed files are ignored.
class LevelCreatorViewStore {
  const LevelCreatorViewStore.local() : directoryPath = null;
  const LevelCreatorViewStore.at(this.directoryPath);

  final String? directoryPath;
  static Future<void> _queue = Future.value();

  File? _file(String workspacePath) {
    final base = directoryPath ?? _localDirectory();
    if (base == null) return null;
    final absolute = p.normalize(p.absolute(workspacePath));
    final key = Platform.isWindows ? absolute.toLowerCase() : absolute;
    final digest = sha256.convert(utf8.encode(key));
    return File(p.join(base, '$digest.json'));
  }

  static String? _localDirectory() {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) return null;
    return p.join(local, 'rpg_runner', 'editor', 'level_views');
  }

  Future<LevelCreatorReturnContext?> read(String workspacePath) async {
    try {
      final file = _file(workspacePath);
      if (file == null || !await file.exists() || await file.length() > 4096) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return null;
      }
      final id = decoded['levelId'];
      final tabName = decoded['tab'];
      final group = decoded['groupFilter'];
      if (id is! String || id.isEmpty || (group != null && group is! String)) {
        return null;
      }
      final tab = LevelCreatorTab.values
          .where((tab) => tab.name == tabName)
          .firstOrNull;
      if (tab == null) return null;
      return LevelCreatorReturnContext(
        levelId: id,
        tab: tab,
        groupFilter: group as String?,
      );
    } on Object {
      return null;
    }
  }

  Future<void> write(String workspacePath, LevelCreatorReturnContext view) {
    // Serialize rapid tab/filter changes so an older async write cannot win.
    _queue = _queue.then((_) async {
      try {
        final file = _file(workspacePath);
        if (file == null) return;
        await file.parent.create(recursive: true);
        await file.writeAsString(
          jsonEncode({
            'version': 1,
            'levelId': view.levelId,
            'tab': view.tab.name,
            'groupFilter': view.groupFilter,
          }),
          flush: true,
        );
      } on Object {
        // Losing convenience state must never interrupt an authored save.
      }
    });
    return _queue;
  }
}
