import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:run_protocol/replay_blob.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';

import 'ghost_playback_source.dart';
import 'ghost_render_frame.dart';

/// Run-owned playback buffer; advancing the live tick never performs simulation.
///
/// Prefills during loading, then refills at half capacity with one outstanding
/// batch. Every sample/event is consumed in tick order and at most once.
/// On underrun the latest available pose freezes until the worker catches up;
/// live gameplay is never delayed. Failures clear the optional ghost.
class BufferedGhostPlayback extends ChangeNotifier {
  BufferedGhostPlayback({
    required this.replayBlob,
    GhostPlaybackSource Function(ReplayBlobV1)? sourceFactory,
  }) : _sourceFactory = sourceFactory ?? GhostPlaybackSource.start;

  /// Includes queued frames plus slots reserved by the outstanding batch.
  /// Two seconds at 60 Hz amortize message overhead while bounding retained data.
  static const capacity = GhostPlaybackSource.maxBatchFrames;

  final ReplayBlobV1 replayBlob;
  final GhostPlaybackSource Function(ReplayBlobV1) _sourceFactory;
  final ListQueue<GhostPlaybackSample> _buffer = ListQueue();
  GhostPlaybackSource? _source;
  Future<List<ActorFrameSnapshot>>? _preparation;
  GhostPlaybackSample? _current;
  GhostRenderFrame? _frame;
  Object? _error;
  int _lastProducedTick = -1;
  int _wantedTick = 0;
  bool _sourceFinished = false;
  bool _refilling = false;
  bool _disposed = false;

  /// Atomic publication; unchanged when no new tick or freeze is available.
  GhostRenderFrame? get frame => _frame;
  Object? get error => _error;
  bool get isComplete => _current?.isComplete ?? false;

  @visibleForTesting
  int get debugBufferedFrameCount => _buffer.length;
  @visibleForTesting
  int get debugBufferedThroughTick => _lastProducedTick;
  @visibleForTesting
  bool get debugRefilling => _refilling;

  /// Starts the producer and fills the first bounded window before Start.
  /// Returns preview snapshots solely for render asset warmup. A failed or
  /// cancelled preparation returns no previews; [error] records actual failure.
  Future<List<ActorFrameSnapshot>> prepare() => _preparation ??= _prepare();

  Future<List<ActorFrameSnapshot>> _prepare() async {
    if (_disposed) return const [];
    try {
      _source = _sourceFactory(replayBlob);
      final samples = await _source!.read(capacity);
      if (_disposed) return const [];
      _accept(samples, capacity);
      final initial = _buffer.removeFirst();
      _current = initial;
      _frame = GhostRenderFrame(
        replayBlob: replayBlob,
        previous: initial.snapshot,
        current: initial.snapshot,
        events: initial.events,
      );
      final preview = List<ActorFrameSnapshot>.unmodifiable([
        initial.snapshot,
        ..._buffer.map((sample) => sample.snapshot),
      ]);
      notifyListeners();
      if (_disposed) return const [];
      _consumeAvailable();
      _requestRefill();
      return preview;
    } catch (error) {
      if (!_disposed) _fail(error);
      return const [];
    }
  }

  /// Requests a monotonically increasing live simulation tick (never seconds).
  /// This only consumes ready data and schedules asynchronous production.
  void advanceToTick(int targetTick) {
    if (_disposed || _error != null || isComplete) return;
    _wantedTick = math.max(_wantedTick, math.max(0, targetTick));
    if (_current == null) return;
    _consumeAvailable();
    _requestRefill();
  }

  void _consumeAvailable() {
    if (_disposed || _current == null) return;
    var previous = _current!.snapshot;
    var advanced = false;
    final events = <GameEvent>[];
    while (_buffer.isNotEmpty && _buffer.first.snapshot.tick <= _wantedTick) {
      previous = _current!.snapshot;
      _current = _buffer.removeFirst();
      events.addAll(_current!.events);
      advanced = true;
    }
    final current = _current!.snapshot;
    final frozen = isComplete || current.tick < _wantedTick;
    if (!advanced) {
      // Stop replaying the old interpolation pair during a worker underrun.
      if (!frozen || identical(_frame!.previous, current)) return;
    }
    _frame = GhostRenderFrame(
      replayBlob: replayBlob,
      previous: frozen ? current : previous,
      current: current,
      events: events,
    );
    notifyListeners();
  }

  void _requestRefill() {
    if (_disposed ||
        _error != null ||
        _refilling ||
        _sourceFinished ||
        _current == null ||
        _buffer.length > capacity ~/ 2) {
      return;
    }
    unawaited(_refill());
  }

  Future<void> _refill() async {
    _refilling = true;
    try {
      do {
        final count = capacity - _buffer.length;
        final samples = await _source!.read(count);
        if (_disposed) return;
        _accept(samples, count);
        _consumeAvailable();
      } while (!_disposed &&
          !_sourceFinished &&
          _buffer.length <= capacity ~/ 2);
    } catch (error) {
      if (!_disposed) _fail(error);
    } finally {
      _refilling = false;
    }
  }

  void _accept(List<GhostPlaybackSample> samples, int requested) {
    if (samples.isEmpty ||
        samples.length > requested ||
        _buffer.length + samples.length > capacity) {
      throw StateError('Invalid ghost playback batch size.');
    }
    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];
      if (sample.snapshot.tick != _lastProducedTick + 1 ||
          sample.isComplete != sample.snapshot.gameOver ||
          (sample.isComplete && i != samples.length - 1)) {
        throw StateError('Ghost playback samples are out of order.');
      }
      _lastProducedTick = sample.snapshot.tick;
    }
    if (samples.length < requested && !samples.last.isComplete) {
      throw StateError('Nonterminal ghost batch was truncated.');
    }
    _buffer.addAll(samples);
    if (samples.last.isComplete) {
      _sourceFinished = true;
      _source?.dispose();
      _source = null;
    }
  }

  void _fail(Object error) {
    _error = error;
    _source?.dispose();
    _source = null;
    _buffer.clear();
    _current = null;
    _frame = null;
    notifyListeners();
  }

  /// Stops the worker, releases frames, and fences every late async result.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _source?.dispose();
    _source = null;
    _buffer.clear();
    _current = null;
    _frame = null;
    super.dispose();
  }
}
