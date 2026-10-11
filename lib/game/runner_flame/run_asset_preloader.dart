import 'dart:async';
import 'dart:collection';

import 'package:flame/cache.dart';

/// Bounded, deduplicated startup reads into the run's existing Flame cache.
///
/// Registries retain their asset manifests and sprite construction. Each group
/// can build as soon as its own images arrive; unrelated groups keep loading.
/// The owner must cancel this loader when abandoning startup and wait for its
/// consumers before clearing images decoded by already-running reads.
final class RunAssetPreloader {
  RunAssetPreloader(this.images, {this.concurrency = 8}) {
    if (concurrency < 1) throw ArgumentError.value(concurrency, 'concurrency');
  }

  final Images images;

  /// Eight concurrent reads overlap I/O without decoding the entire catalog at
  /// once. This limits this preloader; terrain and parallax have separate loads.
  final int concurrency;
  final Map<String, Future<void>> _loads = {};
  final Queue<(String, Completer<void>)> _queue = Queue();
  int _active = 0;
  bool _cancelled = false;

  /// Loads each unique source once, then lets its registry build from the cache.
  /// Failures retain their stack, and completion drains every read in the group.
  Future<T> load<T>(Iterable<String> paths, Future<T> Function() build) async {
    if (_cancelled) throw StateError('Run asset loading cancelled.');
    await Future.wait(paths.toSet().map(_enqueue));
    if (_cancelled) throw StateError('Run asset loading cancelled.');
    return build();
  }

  Future<void> _enqueue(String path) => _loads.putIfAbsent(path, () {
    final completion = Completer<void>();
    _queue.add((path, completion));
    _pump();
    return completion.future;
  });

  void _pump() {
    while (!_cancelled && _active < concurrency && _queue.isNotEmpty) {
      final (path, completion) = _queue.removeFirst();
      _active++;
      unawaited(_read(path, completion));
    }
  }

  Future<void> _read(String path, Completer<void> completion) async {
    try {
      await images.load(path);
      completion.complete();
    } catch (error, stack) {
      completion.completeError(error, stack);
    } finally {
      _active--;
      _pump();
    }
  }

  /// Stops queued work; in-flight decodes still belong to the closing run.
  void cancel() {
    _cancelled = true;
    while (_queue.isNotEmpty) {
      _queue.removeFirst().$2.completeError(
        StateError('Run asset loading cancelled.'),
      );
    }
  }
}
