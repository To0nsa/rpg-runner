import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:run_protocol/board_key.dart';
import 'package:run_protocol/codecs/canonical_json_codec.dart';
import 'package:run_protocol/replay_blob.dart';

import 'replay_quantization.dart';

/// Immutable metadata for one local replay recording session.
class RunRecorderHeader {
  const RunRecorderHeader({
    required this.runSessionId,
    required this.tickHz,
    required this.seed,
    required this.levelId,
    required this.playerCharacterId,
    required this.loadoutSnapshot,
    this.boardId,
    this.boardKey,
  });

  final String runSessionId;
  final String? boardId;
  final BoardKey? boardKey;
  final int tickHz;
  final int seed;
  final String levelId;
  final String playerCharacterId;
  final Map<String, Object?> loadoutSnapshot;
}

/// Finalized recorder artifacts.
class RunRecorderFinalizeResult {
  const RunRecorderFinalizeResult({
    required this.replayBlob,
    required this.replayBlobFile,
    required this.spoolFile,
    required this.streamDigestSha256,
    required this.framesRecorded,
  });

  final ReplayBlobV1 replayBlob;
  final File replayBlobFile;
  final File spoolFile;
  final String streamDigestSha256;
  final int framesRecorded;
}

/// File-backed replay recorder.
///
/// Appends one canonical frame per line (NDJSON) to a spool file while keeping
/// an incremental stream digest. Finalization materializes `ReplayBlobV1`.
class RunRecorder {
  RunRecorder._({
    required this.header,
    required this.spoolFile,
    required this.replayBlobFile,
    required IOSink spoolSink,
  }) : _spoolSink = spoolSink;

  final RunRecorderHeader header;
  final File spoolFile;
  final File replayBlobFile;

  final IOSink _spoolSink;
  final _DigestAccumulator _streamDigestAccumulator = _DigestAccumulator();
  late final ByteConversionSink _streamDigestSink =
      sha256.startChunkedConversion(_streamDigestAccumulator);

  var _framesRecorded = 0;
  var _maxTick = 0;
  var _isClosed = false;
  RunRecorderFinalizeResult? _finalized;

  static Future<RunRecorder> create({
    required RunRecorderHeader header,
    required Directory spoolDirectory,
    String? fileStem,
  }) async {
    await spoolDirectory.create(recursive: true);

    final stem = fileStem ?? 'run_${header.runSessionId}';
    final spoolFile = File('${spoolDirectory.path}/$stem.frames.ndjson');
    final replayBlobFile = File('${spoolDirectory.path}/$stem.replay.json');

    if (await spoolFile.exists()) {
      await spoolFile.delete();
    }
    if (await replayBlobFile.exists()) {
      await replayBlobFile.delete();
    }

    final sink = spoolFile.openWrite(mode: FileMode.writeOnly);
    return RunRecorder._(
      header: header,
      spoolFile: spoolFile,
      replayBlobFile: replayBlobFile,
      spoolSink: sink,
    );
  }

  void appendFrame(ReplayCommandFrameV1 frame) {
    if (_finalized != null) {
      throw StateError('RunRecorder has already been finalized.');
    }
    if (_isClosed) {
      throw StateError('RunRecorder is already closed.');
    }

    final quantized = ReplayQuantization.quantizeFrame(frame);
    final line = canonicalJsonEncode(quantized.toJson());

    _spoolSink.writeln(line);
    final lineBytes = utf8.encode('$line\n');
    _streamDigestSink.add(lineBytes);

    _framesRecorded += 1;
    if (quantized.tick > _maxTick) {
      _maxTick = quantized.tick;
    }
  }

  Future<RunRecorderFinalizeResult> finalize({
    Map<String, Object?>? clientSummary,
  }) async {
    final cached = _finalized;
    if (cached != null) return cached;

    await _closeSinkIfNeeded();
    _streamDigestSink.close();
    final streamDigest = _streamDigestAccumulator.value.toString();

    final frames = await _readFramesFromSpool();
    final replayBlob = ReplayBlobV1.withComputedDigest(
      runSessionId: header.runSessionId,
      boardId: header.boardId,
      boardKey: header.boardKey,
      tickHz: header.tickHz,
      seed: header.seed,
      levelId: header.levelId,
      playerCharacterId: header.playerCharacterId,
      loadoutSnapshot: header.loadoutSnapshot,
      totalTicks: _maxTick,
      commandStream: frames,
      clientSummary: clientSummary,
    );

    final blobJson = canonicalJsonEncode(replayBlob.toJson());
    await replayBlobFile.writeAsString(blobJson, flush: true);

    final result = RunRecorderFinalizeResult(
      replayBlob: replayBlob,
      replayBlobFile: replayBlobFile,
      spoolFile: spoolFile,
      streamDigestSha256: streamDigest,
      framesRecorded: _framesRecorded,
    );
    _finalized = result;
    return result;
  }

  Future<void> close() async {
    if (_finalized != null) return;
    await _closeSinkIfNeeded();
    _streamDigestSink.close();
  }

  Future<void> _closeSinkIfNeeded() async {
    if (_isClosed) return;
    _isClosed = true;
    await _spoolSink.flush();
    await _spoolSink.close();
  }

  Future<List<ReplayCommandFrameV1>> _readFramesFromSpool() async {
    final lines = await spoolFile.readAsLines();
    final frames = <ReplayCommandFrameV1>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      final decoded = jsonDecode(line);
      frames.add(ReplayCommandFrameV1.fromJson(decoded));
    }
    return List<ReplayCommandFrameV1>.unmodifiable(frames);
  }
}

class _DigestAccumulator implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
