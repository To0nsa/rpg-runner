import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/firebase_environment.dart';

void main() {
  test('Android native configurations agree with the release registry', () {
    final registry = jsonDecode(
      File('tools/release/environments.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final definitions = registry['environments'] as Map<String, dynamic>;
    for (final environment in FirebaseEnvironment.values) {
      final definition = definitions[environment.name] as Map<String, dynamic>;
      expect(environment.projectId, definition['projectId']);
      expect(environment.androidPackage, definition['androidPackage']);
      final configuration = jsonDecode(
        File('android/app/src/${environment.name}/google-services.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final project = configuration['project_info'] as Map<String, dynamic>;
      environment.verifyProject(project['project_id'] as String);
      final clients = configuration['client'] as List<dynamic>;
      expect(
        clients.where(
          (dynamic client) =>
              client['client_info']['android_client_info']['package_name'] ==
              environment.androidPackage,
        ),
        hasLength(1),
      );
    }
  });

  test('every wrong-environment backend is rejected before client wiring', () {
    for (final target in FirebaseEnvironment.values) {
      for (final other in FirebaseEnvironment.values) {
        if (target == other) continue;
        expect(() => target.verifyProject(other.projectId), throwsStateError);
      }
    }
  });

  test('an absent or unknown Android flavor cannot silently select prod', () {
    for (final invalid in [null, '', 'production', 'debug']) {
      expect(
        () => FirebaseEnvironment.fromAndroidFlavor(invalid),
        throwsStateError,
      );
    }
  });

  test(
    'beta flavors require real attestation and link to their own listing',
    () {
      expect(FirebaseEnvironment.dev.usesDebugAppCheck, isTrue);
      for (final environment in [
        FirebaseEnvironment.staging,
        FirebaseEnvironment.prod,
      ]) {
        expect(environment.usesDebugAppCheck, isFalse);
        expect(
          environment.playStoreUri.queryParameters['id'],
          environment.androidPackage,
        );
      }
    },
  );
}
