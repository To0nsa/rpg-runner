import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A child can be asked to cancel; its atomic writer is never forcibly killed.
abstract interface class ContentBuildProcess {
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Future<int> get exitCode;
  void requestCancellation();
}

typedef ContentBuildLauncher = Future<ContentBuildProcess> Function({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
});

Future<ContentBuildProcess> launchContentBuildProcess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
}) async => _DartContentBuildProcess(
  await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  ),
);

final class _DartContentBuildProcess implements ContentBuildProcess {
  _DartContentBuildProcess(this.process) {
    // The child may finish between the UI cancellation request and this pipe
    // write. Its final report/exit remain authoritative in that race.
    unawaited(process.stdin.done.catchError((Object _) {}));
  }
  final Process process;
  @override
  Stream<String> get stdoutLines =>
      process.stdout.transform(utf8.decoder).transform(const LineSplitter());
  @override
  Stream<String> get stderrLines =>
      process.stderr.transform(utf8.decoder).transform(const LineSplitter());
  @override
  Future<int> get exitCode => process.exitCode;
  @override
  void requestCancellation() {
    try {
      process.stdin.writeln('cancel');
    } on Object {
      /* Child already exited. */
    }
  }
}

/// Resolves an actual Dart SDK binary without invoking a command shell or wrapper.
Future<String> resolveContentBuildDartExecutable() async {
  final binary = Platform.isWindows ? 'dart.exe' : 'dart';
  final candidates = <String>{};
  if (p.basename(Platform.resolvedExecutable).toLowerCase() == binary) {
    candidates.add(Platform.resolvedExecutable);
  }
  for (final directory in (Platform.environment['PATH'] ?? '').split(
    Platform.isWindows ? ';' : ':',
  )) {
    if (directory.trim().isEmpty) continue;
    candidates.add(p.join(directory, binary));
    candidates.add(p.join(directory, 'cache', 'dart-sdk', 'bin', binary));
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    candidates.add(
      p.join(flutterRoot, 'bin', 'cache', 'dart-sdk', 'bin', binary),
    );
  }
  for (final candidate in candidates) {
    final file = File(candidate);
    if (await file.exists()) return file.resolveSymbolicLinks();
  }
  throw const FileSystemException(
    'Dart SDK executable is unavailable. Install or configure the Flutter/Dart SDK and reopen the editor.',
  );
}
