import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/traps/trap_id.dart';
import 'package:test/test.dart';

Map<String, dynamic> trap({int x = 200}) => {
  'trapId': 'spike',
  'x': x,
  'y': 128,
  'trigger': {'offsetX': -40, 'offsetY': -20, 'width': 80, 'height': 40},
};

void main() {
  decode(Object? source) => decodeTrapPlacements(
    source,
    sourcePath: 'fixture.traps',
    chunkWidth: 960,
    chunkHeight: 320,
  );

  test('explicit saved geometry survives immutable decode and round trip', () {
    final result = decode([trap()]);
    expect(result.single.trapId, TrapId.spike);
    expect(result.single.toJson(), trap());
    expect(result.single.zIndex, -21);
    expect(() => result.clear(), throwsUnsupportedError);
    expect(decode([]), isEmpty);
  });

  test(
    'optional tuning round trips and explicit defaults canonicalize away',
    () {
      final tuned = {...trap(), 'damage100': 125, 'windupMs': 0, 'zIndex': 7};
      expect(decode([tuned]).single.toJson(), tuned);
      expect(
        decode([
          {...trap(), 'damage100': 500, 'windupMs': 700, 'zIndex': -21},
        ]).single.toJson(),
        trap(),
      );
      for (final fields in [
        {'zIndex': null},
        {'zIndex': 1.5},
        {'zIndex': '2'},
        {'damage100': null},
        {'damage100': 1.0},
        {'damage100': '100'},
        {'damage100': 0},
        {'damage100': 100001},
        {'windupMs': null},
        {'windupMs': 0.5},
        {'windupMs': '100'},
        {'windupMs': -1},
        {'windupMs': 30001},
      ]) {
        expect(
          () => decode([
            {...trap(), ...fields},
          ]),
          throwsFormatException,
        );
      }
    },
  );

  test('invalid, coerced, unordered and unknown source fails closed', () {
    for (final source in [
      null,
      {},
      [null],
      [
        {...trap(), 'trapId': 'unknown'},
      ],
      [
        {...trap(), 'x': 200.0},
      ],
      [
        {...trap(), 'facing': 'left'},
      ],
      [
        {...trap(), 'trapId': 'swinging_axe'},
      ],
      [
        {...trap(), 'trapId': 'poison_darts', 'facing': 'up'},
      ],
      [
        {...trap(), 'damage': 5},
      ],
      [
        {...trap(), 'trigger': null},
      ],
      [
        {
          ...trap(),
          'trigger': {'offsetX': 0, 'offsetY': 0, 'width': -1, 'height': 1},
        },
      ],
      [trap(x: 10)],
      [trap(x: 940)],
      [trap(x: 201), trap()],
      [trap(), trap()],
      [for (var i = 0; i < 9; i++) trap(x: 200 + i)],
    ]) {
      expect(() => decode(source), throwsFormatException, reason: '$source');
    }
  });
}
