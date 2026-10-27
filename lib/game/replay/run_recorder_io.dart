import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:run_protocol/codecs/canonical_json_codec.dart';
import 'package:run_protocol/replay_blob.dart';

import 'replay_quantization.dart';
import 'replay_spool_directory_io.dart';
import 'run_recorder.dart';

Future<RunRecorder> createRunRecorder(RunRecorderHeader header) =>
    FileRunRecorder.create(header: header, fileStem: header.runSessionId);

/// File-backed replay recorder.
///
/// Appends one canonical frame per line (NDJSON) to a spool file while keeping
/// an incremental stream digest. Finalization materializes `ReplayBlobV1`.
class FileRunRecorder implements RunRecorder {
  FileRunRecorder._({
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
  late final ByteConversionSink _streamDigestSink = sha256
      .startChunkedConversion(_streamDigestAccumulator);

  var _framesRecorded = 0;
  var _maxTick = 0;
  var _isClosed = false;
  RunRecorderFinalizeResult? _finalized;

  static Future<RunRecorder> create({
    required RunRecorderHeader header,
    Directory? spoolDirectory,
    String? fileStem,
  }) async {
    spoolDirectory ??= defaultReplaySpoolDirectory();
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
    try {
      // An empty add starts the lazy sink consumer; flush alone is a no-op
      // before the first add. Await the file open without writing a frame.
      sink.add(const <int>[]);
      await sink.flush();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {
        // Preserve the initialization error from flush.
      }
      rethrow;
    }
    return FileRunRecorder._(
      header: header,
      spoolFile: spoolFile,
      replayBlobFile: replayBlobFile,
      spoolSink: sink,
    );
  }

  @override
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

  @override
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
      replayArtifactId: replayBlobFile.path,
      contentLengthBytes: await replayBlobFile.length(),
      streamDigestSha256: streamDigest,
      framesRecorded: _framesRecorded,
    );
    _finalized = result;
    return result;
  }

  @override
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
