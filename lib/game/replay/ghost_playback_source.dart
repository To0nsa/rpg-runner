import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';
import 'package:run_protocol/replay_blob.dart';

import 'ghost_playback_runner.dart';

/// One fully simulated tick; event ownership transfers with the immutable sample.
class GhostPlaybackSample {
  GhostPlaybackSample({
    required this.snapshot,
    required this.isComplete,
    required Iterable<GameEvent> events,
  }) : events = List<GameEvent>.unmodifiable(events);

  final ActorFrameSnapshot snapshot;
  final bool isComplete;
  final List<GameEvent> events;
}

/// Sequential, bounded replay production, isolated from the live controller.
///
/// The first read includes tick zero. Later reads continue at the next tick.
/// A nonempty short batch ends with a terminal sample; later reads are empty.
/// Only one read may be outstanding. Dispose cancels pending work.
abstract class GhostPlaybackSource {
  /// 120 compact frames cover two seconds at 60 Hz without retaining a full run.
  static const maxBatchFrames = 120;

  /// Starts one persistent native isolate, or cooperative slices on the web.
  /// Native construction and terrain preparation happen inside the worker.
  static GhostPlaybackSource start(ReplayBlobV1 replay) =>
      kIsWeb ? cooperative(replay) : _IsolateGhostPlaybackSource(replay);

  /// Uses the same deterministic producer, yielding between short CPU slices.
  /// This supports platforms without isolates; a single Core tick is indivisible.
  static GhostPlaybackSource cooperative(ReplayBlobV1 replay) =>
      _CooperativeGhostPlaybackSource(replay);

  Future<List<GhostPlaybackSample>> read(int maxFrames);
  void dispose();
}

void _checkBatchSize(int maxFrames) {
  if (maxFrames < 1 || maxFrames > GhostPlaybackSource.maxBatchFrames) {
    throw RangeError.range(
      maxFrames,
      1,
      GhostPlaybackSource.maxBatchFrames,
      'maxFrames',
    );
  }
}

class _Producer {
  _Producer(ReplayBlobV1 replay)
    : runner = GhostPlaybackRunner.fromReplayBlob(replay);

  final GhostPlaybackRunner runner;
  bool _initial = true;

  GhostPlaybackSample? next() {
    if (!_initial && runner.isComplete) return null;
    runner.advanceToTick(_initial ? 0 : runner.tick + 1);
    _initial = false;
    final sample = GhostPlaybackSample(
      snapshot: runner.snapshot,
      isComplete: runner.isComplete,
      events: runner.drainedEvents,
    );
    runner.clearDrainedEvents();
    return sample;
  }
}

class _CooperativeGhostPlaybackSource implements GhostPlaybackSource {
  _CooperativeGhostPlaybackSource(this.replay);

  final ReplayBlobV1 replay;
  _Producer? _producer;
  bool _disposed = false;
  bool _reading = false;

  @override
  Future<List<GhostPlaybackSample>> read(int maxFrames) async {
    _checkBatchSize(maxFrames);
    if (_disposed) throw StateError('Ghost playback source disposed.');
    if (_reading) throw StateError('A ghost batch is already pending.');
    _reading = true;
    try {
      // Defer construction until after the loading presentation can be painted.
      await Future<void>.delayed(Duration.zero);
      if (_disposed) throw StateError('Ghost playback source disposed.');
      if (_producer == null) {
        _producer = _Producer(replay);
        await _producer!.runner.prepareTerrainAhead();
      }
      final samples = <GhostPlaybackSample>[];
      final slice = Stopwatch()..start();
      while (!_disposed && samples.length < maxFrames) {
        final sample = _producer!.next();
        if (sample == null) break;
        samples.add(sample);
        if (sample.isComplete) break;
        // A 2 ms target leaves most of a 60/120 Hz frame for live work.
        if (slice.elapsedMicroseconds >= 2000) {
          await Future<void>.delayed(Duration.zero);
          slice.reset();
        }
      }
      if (_disposed) throw StateError('Ghost playback source disposed.');
      return samples;
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _producer?.runner.dispose();
    _producer = null;
  }
}

class _IsolateGhostPlaybackSource implements GhostPlaybackSource {
  _IsolateGhostPlaybackSource(ReplayBlobV1 replay) {
    _replies.listen(_onReply);
    _errors.listen((dynamic message) {
      final parts = message as List<dynamic>;
      _fail(RemoteError(parts[0].toString(), parts[1].toString()));
    });
    _exits.listen((_) {
      if (!_disposed) _fail(StateError('Ghost playback worker exited.'));
    });
    unawaited(_spawn(replay));
  }

  // Bounds a dead worker/startup independently of live gameplay or route exit.
  static const _responseTimeout = Duration(seconds: 30);
  final ReceivePort _replies = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exits = ReceivePort();
  Isolate? _isolate;
  SendPort? _commands;
  Completer<List<GhostPlaybackSample>>? _pending;
  int? _pendingCount;
  Object? _failure;
  bool _disposed = false;

  Future<void> _spawn(ReplayBlobV1 replay) async {
    try {
      final isolate = await Isolate.spawn(
        _runGhostWorker,
        (replay: replay, replies: _replies.sendPort),
        onError: _errors.sendPort,
        onExit: _exits.sendPort,
        debugName: 'ghost-playback',
      );
      if (_disposed) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    } catch (error) {
      _fail(error);
    }
  }

  @override
  Future<List<GhostPlaybackSample>> read(int maxFrames) {
    _checkBatchSize(maxFrames);
    if (_failure != null) return Future.error(_failure!);
    if (_disposed) {
      return Future.error(StateError('Ghost playback source disposed.'));
    }
    if (_pending != null) {
      return Future.error(StateError('A ghost batch is already pending.'));
    }
    final pending = Completer<List<GhostPlaybackSample>>();
    _pending = pending;
    _pendingCount = maxFrames;
    _sendPendingRead();
    return pending.future.timeout(
      _responseTimeout,
      onTimeout: () {
        final error = TimeoutException(
          'Ghost playback worker did not respond.',
          _responseTimeout,
        );
        _fail(error);
        throw error;
      },
    );
  }

  void _sendPendingRead() {
    if (_commands == null || _pendingCount == null || _disposed) return;
    _commands!.send(_pendingCount);
    _pendingCount = null;
  }

  void _onReply(dynamic message) {
    if (_disposed) return;
    if (message is SendPort) {
      _commands = message;
      _sendPendingRead();
    } else if (message is List<GhostPlaybackSample>) {
      final pending = _pending;
      _pending = null;
      pending?.complete(message);
    } else {
      _fail(StateError('Invalid ghost worker reply.'));
    }
  }

  void _fail(Object error) {
    if (_disposed) return;
    _failure = error;
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final pending = _pending;
    _pending = null;
    _pendingCount = null;
    pending?.completeError(
      _failure ?? StateError('Ghost playback source disposed.'),
    );
    _commands?.send(null);
    _commands = null;
    _isolate?.kill();
    _isolate = null;
    _replies.close();
    _errors.close();
    _exits.close();
  }
}

// Top-level entrypoint prevents capturing controllers, widgets, or UI resources.
Future<void> _runGhostWorker(
  ({ReplayBlobV1 replay, SendPort replies}) request,
) async {
  final producer = _Producer(request.replay);
  final commands = ReceivePort();
  try {
    await producer.runner.prepareTerrainAhead();
    request.replies.send(commands.sendPort);
    await for (final dynamic message in commands) {
      if (message == null) break;
      final count = message as int;
      _checkBatchSize(count);
      final samples = <GhostPlaybackSample>[];
      for (var i = 0; i < count; i++) {
        final sample = producer.next();
        if (sample == null) break;
        samples.add(sample);
        if (sample.isComplete) break;
      }
      request.replies.send(samples);
    }
  } finally {
    producer.runner.dispose();
    commands.close();
  }
}
