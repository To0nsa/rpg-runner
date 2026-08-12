import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_validation.dart';

void main() {
  test('layer CRUD and reorder keep revisions deterministic', () {
    final plugin = ParallaxDomainPlugin();
    final document = ParallaxDefsDocument(
      workspaceRootPath: '.',
      themes: const <ParallaxThemeDef>[
        ParallaxThemeDef(
          parallaxThemeId: 'field',
          revision: 1,
          layers: <ParallaxLayerDef>[
            ParallaxLayerDef(
              layerKey: 'field_bg_10',
              assetPath: 'assets/images/parallax/field/bg_10.png',
              group: parallaxGroupBackground,
              parallaxFactor: 0.2,
              zOrder: 10,
              opacity: 1.0,
              yOffset: 0.0,
            ),
          ],
        ),
      ],
      baseline: null,
      availableLevelIds: const <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      parallaxThemeIdByLevelId: const <String, String>{'field': 'field'},
    );

    final created =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'create_layer',
                payload: const <String, Object?>{
                  'group': parallaxGroupForeground,
                  'assetPath': 'assets/images/parallax/field/fg_10.png',
                },
              ),
            )
            as ParallaxDefsDocument;
    expect(created.themes.single.revision, 2);
    expect(created.themes.single.layers, hasLength(2));

    final duplicated =
        plugin.applyEdit(
              created,
              AuthoringCommand(
                kind: 'duplicate_layer',
                payload: const <String, Object?>{'layerKey': 'field_bg_10'},
              ),
            )
            as ParallaxDefsDocument;
    expect(duplicated.themes.single.revision, 3);
    expect(duplicated.themes.single.layers, hasLength(3));

    final duplicateKey = duplicated.themes.single.layers
        .firstWhere(
          (layer) =>
              layer.layerKey != 'field_bg_10' &&
              layer.group == parallaxGroupBackground,
        )
        .layerKey;
    final updated =
        plugin.applyEdit(
              duplicated,
              AuthoringCommand(
                kind: 'update_layer',
                payload: <String, Object?>{
                  'layerKey': duplicateKey,
                  'nextLayerKey': 'field_bg_20',
                  'zOrder': 20,
                  'opacity': '0.5',
                },
              ),
            )
            as ParallaxDefsDocument;
    expect(updated.themes.single.revision, 4);
    expect(
      updated.themes.single.layers.any(
        (layer) => layer.layerKey == 'field_bg_20',
      ),
      isTrue,
    );

    final reordered =
        plugin.applyEdit(
              updated,
              AuthoringCommand(
                kind: 'reorder_layer',
                payload: const <String, Object?>{
                  'layerKey': 'field_bg_20',
                  'direction': -1,
                },
              ),
            )
            as ParallaxDefsDocument;
    expect(reordered.themes.single.revision, 5);
    final backgroundLayers = reordered.themes.single.layers
        .where((layer) => layer.group == parallaxGroupBackground)
        .toList(growable: false);
    expect(backgroundLayers.first.layerKey, 'field_bg_20');
    expect(backgroundLayers.first.zOrder, 10);
    expect(backgroundLayers.last.zOrder, 20);

    final removed =
        plugin.applyEdit(
              reordered,
              AuthoringCommand(
                kind: 'remove_layer',
                payload: const <String, Object?>{'layerKey': 'field_bg_20'},
              ),
            )
            as ParallaxDefsDocument;
    expect(removed.themes.single.revision, 6);
    expect(
      removed.themes.single.layers.any(
        (layer) => layer.layerKey == 'field_bg_20',
      ),
      isFalse,
    );
  });

  test('validation reports structural errors and warnings', () async {
    final root = await Directory.systemTemp.createTemp(
      'parallax_plugin_validation_',
    );
    try {
      final document = ParallaxDefsDocument(
        workspaceRootPath: root.path,
        themes: const <ParallaxThemeDef>[
          ParallaxThemeDef(
            parallaxThemeId: 'field',
            revision: 0,
            layers: <ParallaxLayerDef>[
              ParallaxLayerDef(
                layerKey: 'dup_layer',
                assetPath: 'assets/images/missing_bg.png',
                group: parallaxGroupBackground,
                parallaxFactor: 3.0,
                zOrder: 20,
                opacity: 0.1,
                yOffset: 2000,
              ),
              ParallaxLayerDef(
                layerKey: 'dup_layer',
                assetPath: 'assets/images/missing_bg_2.png',
                group: 'unknown',
                parallaxFactor: 0.5,
                zOrder: 10,
                opacity: 2.0,
                yOffset: 0,
              ),
            ],
          ),
        ],
        baseline: null,
        availableLevelIds: const <String>['field'],
        activeLevelId: 'field',
        levelOptionSource: 'test',
        parallaxThemeIdByLevelId: const <String, String>{'field': 'field'},
      );

      final codes = validateParallaxDocument(
        document,
      ).map((issue) => issue.code).toSet();

      expect(codes, contains('invalid_revision'));
      expect(codes, contains('duplicate_layer_key'));
      expect(codes, contains('invalid_layer_asset_path'));
      expect(codes, contains('invalid_layer_group'));
      expect(codes, contains('parallax_factor_out_of_range'));
      expect(codes, contains('opacity_out_of_range'));
      expect(codes, contains('very_low_opacity'));
      expect(codes, contains('large_y_offset'));
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('setting a shared Y offset replaces every active-theme layer value', () {
    final plugin = ParallaxDomainPlugin();
    const document = ParallaxDefsDocument(
      workspaceRootPath: '.',
      themes: <ParallaxThemeDef>[
        ParallaxThemeDef(
          parallaxThemeId: 'field',
          revision: 4,
          layers: <ParallaxLayerDef>[
            ParallaxLayerDef(
              layerKey: 'field_bg',
              assetPath: 'assets/images/parallax/field/bg.png',
              group: parallaxGroupBackground,
              parallaxFactor: 0.2,
              zOrder: 10,
              opacity: 1,
              yOffset: -16,
            ),
            ParallaxLayerDef(
              layerKey: 'field_fg',
              assetPath: 'assets/images/parallax/field/fg.png',
              group: parallaxGroupForeground,
              parallaxFactor: 1,
              zOrder: 10,
              opacity: 1,
              yOffset: 32,
            ),
          ],
        ),
      ],
      baseline: null,
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      parallaxThemeIdByLevelId: <String, String>{'field': 'field'},
    );

    final updated =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'set_active_theme_y_offsets',
                payload: <String, Object?>{'yOffset': 0},
              ),
            )
            as ParallaxDefsDocument;

    expect(updated.themes.single.revision, 5);
    expect(updated.themes.single.layers.map((layer) => layer.yOffset), <double>[
      0,
      0,
    ]);
  });

  test(
    'shared Y offset does not apply when it exceeds the supported range',
    () {
      final plugin = ParallaxDomainPlugin();
      const document = ParallaxDefsDocument(
        workspaceRootPath: '.',
        themes: <ParallaxThemeDef>[
          ParallaxThemeDef(
            parallaxThemeId: 'field',
            revision: 1,
            layers: <ParallaxLayerDef>[
              ParallaxLayerDef(
                layerKey: 'field_bg',
                assetPath: 'assets/images/parallax/field/bg.png',
                group: parallaxGroupBackground,
                parallaxFactor: 0.2,
                zOrder: 10,
                opacity: 1,
                yOffset: maxAbsYOffset,
              ),
            ],
          ),
        ],
        baseline: null,
        availableLevelIds: <String>['field'],
        activeLevelId: 'field',
        levelOptionSource: 'test',
        parallaxThemeIdByLevelId: <String, String>{'field': 'field'},
      );

      final rejected =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: 'set_active_theme_y_offsets',
                  payload: <String, Object?>{'yOffset': maxAbsYOffset + 1},
                ),
              )
              as ParallaxDefsDocument;

      expect(rejected.themes.single, document.themes.single);
      expect(
        rejected.operationIssues.single.code,
        'set_active_theme_y_offsets_out_of_range',
      );
    },
  );
}
