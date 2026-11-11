import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'localization_checks.dart';

const _owners = ['.', 'packages/game_presentation'];
const _sourceRoots = ['lib/ui', 'lib/game', 'packages/game_presentation/lib'];

/// Run at the workspace root. Check generates only in a fresh temporary directory;
/// it never repairs source or masks drift by changing checked-in outputs.
Future<void> main(List<String> args) async {
  if (args.length > 1 ||
      (args.isNotEmpty &&
          !{'check', 'generate', 'audit'}.contains(args.single))) {
    stderr.writeln(
      'Usage: dart run tool/localization.dart [check|generate|audit]',
    );
    exitCode = 64;
    return;
  }
  final mode = args.firstOrNull ?? 'check';
  if (mode == 'generate') {
    for (final owner in _owners) {
      if (!await _generate(Directory(owner))) {
        exitCode = 1;
        return;
      }
    }
    return;
  }
  final errors = <String>[];
  final localeSets = <Set<String>>[];
  for (final owner in _owners) {
    final config =
        loadYaml(File('$owner/l10n.yaml').readAsStringSync()) as YamlMap;
    final resources = Directory('$owner/${config['arb-dir']}');
    final files = resources
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();
    final english = jsonDecode(
      File('${resources.path}/${config['template-arb-file']}')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    if (english['@@locale'] != 'en') {
      errors.add('$owner: template source locale must be English');
    }
    final locales = <String>{};
    for (final file in files) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final locale = data['@@locale'];
      if (locale is! String || !locales.add(locale)) {
        errors.add('${file.path}: missing/duplicate locale');
      }
      errors.addAll(
        checkResources(english, data).map((error) => '${file.path}: $error'),
      );
    }
    if (!locales.containsAll(['en', 'fr'])) {
      errors.add('$owner: English source and French translation are required');
    }
    localeSets.add(locales);
    if (mode != 'audit' && !await _fresh(owner, config, files)) {
      errors.add('$owner: generated localization drift (run generate)');
    }
  }
  if (localeSets[0].length != localeSets[1].length ||
      !localeSets[0].containsAll(localeSets[1])) {
    errors.add('App/shared supported locales differ');
  }
  final groups = jsonDecode(
    File('tool/localization_exceptions.json').readAsStringSync(),
  ) as List;
  final exceptions = [
    for (final group in groups)
      for (final literal in group['literals'] as List)
        {'file': group['file'], 'literal': literal, 'reason': group['reason']},
  ];
  final used = <int>{};
  for (final root in _sourceRoots) {
    for (final file in Directory(
      root,
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') ||
          path.contains('/l10n/generated/') ||
          path == 'lib/ui/campaign/generated_campaign_catalog.dart' ||
          path == 'lib/ui/levels/generated_level_ui_metadata.dart' ||
          path == 'lib/game/themes/authored_parallax_themes.dart' ||
          path == 'lib/game/themes/authored_terrain_materials.dart') {
        continue;
      }
      for (final text in hardcodedText(file.readAsStringSync(), path)) {
        final index = exceptions.indexWhere(
          (entry) =>
              entry['file'] == path &&
              entry['literal'] == text.source &&
              (entry['reason'] as String? ?? '').trim().isNotEmpty,
        );
        if (index < 0) {
          errors.add('$path:${text.line}: hardcoded ${text.source}');
        } else {
          used.add(index);
        }
      }
    }
  }
  for (var i = 0; i < exceptions.length; i++) {
    if (!used.contains(i)) {
      errors.add('Stale/invalid exemption: ${exceptions[i]}');
    }
  }
  for (final error in errors) {
    stderr.writeln(error);
  }
  if (errors.isNotEmpty) {
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Localization ${mode == 'audit' ? 'resources/source audit' : 'check'} passed (${localeSets.first.join(', ')}).',
  );
}

Future<bool> _generate(Directory directory) async {
  final result = await Process.run(
    Platform.isWindows ? 'flutter.bat' : 'flutter',
    ['gen-l10n'],
    workingDirectory: directory.path,
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    stderr.write(result.stdout);
    stderr.write(result.stderr);
  }
  return result.exitCode == 0;
}

Future<bool> _fresh(String owner, YamlMap config, List<File> resources) async {
  final temporary = Directory.systemTemp.createTempSync('runner-localization-');
  try {
    File('${temporary.path}/pubspec.yaml').writeAsStringSync(
      'name: localization_check\nenvironment:\n  sdk: ^3.13.1\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  generate: true\n',
    );
    File('$owner/l10n.yaml').copySync('${temporary.path}/l10n.yaml');
    final arb = Directory('${temporary.path}/${config['arb-dir']}')
      ..createSync(recursive: true);
    for (final file in resources) {
      file.copySync('${arb.path}/${file.uri.pathSegments.last}');
    }
    if (!await _generate(temporary)) return false;
    final generated = Directory('${temporary.path}/${config['output-dir']}');
    final checkedIn = Directory('$owner/${config['output-dir']}');
    final fresh = generated
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    if (fresh.length !=
        checkedIn
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .length) {
      return false;
    }
    for (final file in fresh) {
      final other = File('${checkedIn.path}/${file.uri.pathSegments.last}');
      if (!other.existsSync() ||
          file.readAsStringSync().replaceAll('\r\n', '\n') !=
              other.readAsStringSync().replaceAll('\r\n', '\n')) {
        return false;
      }
    }
    final missing = jsonDecode(
      File('${temporary.path}/${config['untranslated-messages-file']}')
          .readAsStringSync(),
    ) as Map;
    return missing.isEmpty;
  } finally {
    // This directory is the unique createTemp result, never a supplied/computed workspace path.
    temporary.deleteSync(recursive: true);
  }
}
