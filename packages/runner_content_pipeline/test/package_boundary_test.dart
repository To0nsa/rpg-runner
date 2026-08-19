import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('production package stays pure Dart and editor independent', () {
    final forbidden = <String>[
      "import 'dart:io'",
      'package:flutter/',
      'package:flame/',
      'tools/editor/',
      "import '../tool/",
      "import '../../tool/",
      "import '../../../tool/",
    ];
    final findings = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) findings.add('${entity.path}: $token');
      }
    }

    expect(findings, isEmpty);
  });

  test('runner_core has no reverse pipeline dependency', () {
    final corePubspec = File('../runner_core/pubspec.yaml').readAsStringSync();

    expect(corePubspec, isNot(contains('runner_content_pipeline')));
  });
}
