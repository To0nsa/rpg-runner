/// Android flavor identity. These values must agree with the release registry
/// and the genuine Firebase configuration packaged by Gradle.
enum FirebaseEnvironment {
  dev('rpg-runner-d7add', 'com.example.rpg_runner.dev'),
  staging('lothringen-long-run-staging', 'com.lothringen.longrun.staging'),
  prod('lothringen-long-run-prod', 'com.example.rpg_runner');

  const FirebaseEnvironment(this.projectId, this.androidPackage);

  final String projectId;
  final String androidPackage;

  bool get usesDebugAppCheck => this == dev;

  Uri get playStoreUri => Uri.https('play.google.com', '/store/apps/details', {
    'id': androidPackage,
  });

  static FirebaseEnvironment fromAndroidFlavor(String? flavor) =>
      switch (flavor) {
        'dev' => dev,
        'staging' => staging,
        'prod' => prod,
        _ => throw StateError('An explicit Android environment is required.'),
      };

  void verifyProject(String actualProjectId) {
    if (actualProjectId != projectId) {
      throw StateError('Packaged Firebase project does not match $name.');
    }
  }
}
