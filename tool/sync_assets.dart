import 'dart:io';

const String _pubspecPath = 'pubspec.yaml';
const String _beginMarker = '# BEGIN AUTO-ASSETS';
const String _endMarker = '# END AUTO-ASSETS';
const List<String> _assetRoots = <String>['assets/images'];

Future<void> main(List<String> args) async {
  final showHelp = args.contains('-h') || args.contains('--help');
  if (showHelp) {
    _printUsage();
    return;
  }

  final unknownArgs = args.where((arg) => arg != '--check').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknownArgs.join(', ')}');
    _printUsage();
    exitCode = 64;
    return;
  }

  final checkOnly = args.contains('--check');

  try {
    final pubspecFile = File(_pubspecPath);
    if (!await pubspecFile.exists()) {
      stderr.writeln('Could not find $_pubspecPath in the current directory.');
      exitCode = 1;
      return;
    }

    final original = await pubspecFile.readAsString();
    final generatedEntries = await _collectAssetDirectories();
    final updated = _replaceAutoAssetsBlock(original, generatedEntries);

    if (updated == original) {
      stdout.writeln('Asset block is up to date.');
      return;
    }

    if (checkOnly) {
      stderr.writeln(
        'Asset block in $_pubspecPath is stale. '
        'Run: dart run tool/sync_assets.dart',
      );
      exitCode = 1;
      return;
    }

    await pubspecFile.writeAsString(updated);
    stdout.writeln(
      'Updated $_pubspecPath with ${generatedEntries.length} asset directories.',
    );
  } on Object catch (error) {
    stderr.writeln('Failed to sync assets: $error');
    exitCode = 1;
  }
}

Future<List<String>> _collectAssetDirectories() async {
  final directories = <String>{};

  for (final root in _assetRoots) {
    final rootDir = Directory(root);
    if (!await rootDir.exists()) {
      stderr.writeln('Skipping missing asset root: $root');
      continue;
    }

    await for (final entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;

      final fileName = _basename(entity.path);
      if (fileName.startsWith('.')) continue;

      final parent = File(entity.path).parent.path;
      final normalizedParent = _normalizePath(parent);
      if (normalizedParent.isEmpty) continue;

      directories.add('$normalizedParent/');
    }
  }

  final sorted = directories.toList()..sort();
  return sorted;
}

String _replaceAutoAssetsBlock(String content, List<String> entries) {
  final lineBreak = content.contains('\r\n') ? '\r\n' : '\n';
  final blockPattern = RegExp(
    r'^([ \t]*)# BEGIN AUTO-ASSETS[ \t]*$.*?^\1# END AUTO-ASSETS[ \t]*$',
    multiLine: true,
    dotAll: true,
  );
  final match = blockPattern.firstMatch(content);

  if (match == null) {
    throw StateError(
      'Could not find "$_beginMarker" and "$_endMarker" markers in '
      '$_pubspecPath.',
    );
  }

  final indent = match.group(1) ?? '';
  final blockLines = <String>[
    '$indent$_beginMarker',
    ...entries.map((entry) => '$indent- $entry'),
    '$indent$_endMarker',
  ];
  final replacement = blockLines.join(lineBreak);
  return content.replaceRange(match.start, match.end, replacement);
}

String _normalizePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slashIndex = normalized.lastIndexOf('/');
  if (slashIndex < 0) return normalized;
  return normalized.substring(slashIndex + 1);
}

void _printUsage() {
  stdout.writeln('Sync flutter asset directories in pubspec.yaml.');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run tool/sync_assets.dart');
  stdout.writeln('  dart run tool/sync_assets.dart --check');
}
