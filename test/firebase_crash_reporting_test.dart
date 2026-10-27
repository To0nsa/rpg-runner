import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/firebase_crash_reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'diagnostics preserve stacks and prior handlers without exception text',
    () async {
      final originalFlutter = FlutterError.onError;
      final originalPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = originalFlutter;
        PlatformDispatcher.instance.onError = originalPlatform;
      });
      var previousCalls = 0;
      FlutterError.onError = (_) => previousCalls++;
      PlatformDispatcher.instance.onError = (_, _) {
        previousCalls++;
        return true;
      };
      final reports = <(String, StackTrace?, bool)>[];
      installCrashErrorHandlers((type, stack, fatal) async {
        reports.add((type, stack, fatal));
      });
      final stack = StackTrace.fromString('package:runner/synthetic.dart:10');
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('sensitive-token-and-player-payload'),
          stack: stack,
        ),
      );
      expect(
        PlatformDispatcher.instance.onError!(ArgumentError('sensitive'), stack),
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(previousCalls, 2);
      expect(reports.map((report) => report.$1), [
        'Unhandled StateError',
        'Unhandled ArgumentError',
      ]);
      expect(reports.map((report) => report.$2), [stack, stack]);
      expect(reports.map((report) => report.$3), [false, true]);
    },
  );

  test(
    'a failed diagnostic upload does not create another uncaught error',
    () async {
      final originalFlutter = FlutterError.onError;
      final originalPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = originalFlutter;
        PlatformDispatcher.instance.onError = originalPlatform;
      });
      FlutterError.onError = (_) {};
      PlatformDispatcher.instance.onError = (_, _) => true;
      installCrashErrorHandlers((_, _, _) async => throw StateError('offline'));
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('fixture')),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
}
