import 'package:runner_core/collision/terrain/terrain_authoring_seam_signature.dart';
import 'package:test/test.dart';

void main() {
  test('sorts directed transitions into the established v1 record', () {
    final signature = TerrainAuthoringSeamSignature(
      <TerrainAuthoringSeamTransition>[
        _transition(left: 'b', right: 'a'),
        _transition(left: 'a', right: 'b'),
      ],
    );

    expect(signature.canonicalRecord, '''authoring-seams-v1
forest|steady-hard:tier=hard>hard|a>b
forest|steady-hard:tier=hard>hard|b>a''');
    expect(
      signature.digest,
      'd8b6b851be68495663655f6230659043de8f610dc9a391f0252856e4a58c6be1',
    );
  });

  test('snapshots input and rejects duplicate or ambiguous records', () {
    final mutable = <TerrainAuthoringSeamTransition>[
      _transition(left: 'a', right: 'b'),
    ];
    final signature = TerrainAuthoringSeamSignature(mutable);
    mutable.clear();

    expect(signature.transitions, hasLength(1));
    expect(
      () => TerrainAuthoringSeamSignature(<TerrainAuthoringSeamTransition>[
        _transition(left: 'a', right: 'b'),
        _transition(left: 'a', right: 'b'),
      ]),
      throwsArgumentError,
    );
    expect(
      () => TerrainAuthoringSeamTransition(
        levelId: 'forest|night',
        transitionId: 'hard',
        leftChunkKey: 'a',
        rightChunkKey: 'b',
      ),
      throwsArgumentError,
    );
    expect(
      () => TerrainAuthoringSeamTransition(
        levelId: 'forest',
        transitionId: 'hard',
        leftChunkKey: 'a>b',
        rightChunkKey: 'b',
      ),
      throwsArgumentError,
    );
  });

  test('empty adjacency is explicit instead of using an empty-byte digest', () {
    final signature = TerrainAuthoringSeamSignature(const []);

    expect(signature.canonicalRecord, terrainAuthoringSeamSignatureFormat);
    expect(
      signature.digest,
      'c11c965911bb3990c762fc8babb016240b06309c1ecaf7c39b8007b8049f08ab',
    );
  });
}

TerrainAuthoringSeamTransition _transition({
  required String left,
  required String right,
}) => TerrainAuthoringSeamTransition(
  levelId: 'forest',
  transitionId: 'steady-hard:tier=hard>hard',
  leftChunkKey: left,
  rightChunkKey: right,
);
