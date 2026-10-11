import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/runner_flame/run_asset_preloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('groups overlap, share sources, and respect the global bound', () async {
    final images = _ControlledImages();
    addTearDown(images.dispose);
    final loader = RunAssetPreloader(images, concurrency: 2);
    var firstBuilt = false;
    var secondBuilt = false;
    final first = loader.load(['a', 'b', 'a'], () async => firstBuilt = true);
    final second = loader.load(['b', 'c'], () async => secondBuilt = true);
    expect(images.requested, ['a', 'b']);
    images.finish('a');
    await _flush();
    expect(images.requested, ['a', 'b', 'c']);
    expect(firstBuilt, isFalse);
    images.finish('b');
    await first;
    expect(firstBuilt, isTrue);
    expect(secondBuilt, isFalse);
    images.finish('c');
    await second;
    expect(secondBuilt, isTrue);
    expect(images.maxActive, 2);
  });

  test(
    'a failed source drains its group and never builds partial art',
    () async {
      final images = _ControlledImages();
      addTearDown(images.dispose);
      final loader = RunAssetPreloader(images, concurrency: 2);
      var built = false;
      var settled = false;
      final pending = loader.load(['a', 'b', 'c'], () async => built = true);
      final checked = expectLater(
        pending,
        throwsStateError,
      ).then((_) => settled = true);
      images.fail('a');
      await _flush();
      expect(images.requested, ['a', 'b', 'c']);
      expect(settled, isFalse);
      images.finish('b');
      images.finish('c');
      await checked;
      expect(built, isFalse);
    },
  );

  test(
    'cancellation skips queued reads and fences a late successful decode',
    () async {
      final images = _ControlledImages();
      addTearDown(images.dispose);
      final loader = RunAssetPreloader(images, concurrency: 1);
      var built = false;
      final pending = loader.load(['a', 'b'], () async => built = true);
      final checked = expectLater(pending, throwsStateError);
      loader.cancel();
      loader.cancel();
      images.finish('a');
      await checked;
      expect(images.requested, ['a']);
      expect(built, isFalse);
      await expectLater(loader.load(['c'], () async {}), throwsStateError);
      expect(images.requested, ['a']);
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _ControlledImages extends Images {
  final requested = <String>[];
  final pending = <String, Completer<ui.Image>>{};
  final decoded = <ui.Image>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<ui.Image> load(String fileName, {String? key, String? package}) {
    requested.add(fileName);
    active++;
    if (active > maxActive) maxActive = active;
    return (pending[fileName] = Completer<ui.Image>()).future;
  }

  void finish(String path) {
    active--;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    picture.dispose();
    decoded.add(image);
    pending[path]!.complete(image);
  }

  void fail(String path) {
    active--;
    pending[path]!.completeError(StateError('Missing image'));
  }

  void dispose() {
    for (final image in decoded) {
      image.dispose();
    }
  }
}
