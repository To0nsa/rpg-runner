import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:replay_validator/replay_validator.dart';
import 'package:replay_validator/src/replay_benchmark.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'benchmark') {
    exitCode = runReplayBenchmark(args.skip(1).toList(growable: false));
    return;
  }
  final app = ReplayValidatorApp.fromEnvironment();
  final server = await shelf_io.serve(
    app.handler,
    InternetAddress.anyIPv4,
    app.port,
  );
  stdout.writeln(
    'replay-validator listening on http://${server.address.host}:${server.port}',
  );
}
