import 'package:flutter/foundation.dart';

import '../../../../prefabs/models/models.dart';
import 'prefab_editor_data_reducer.dart';
import 'prefab_form_state.dart';

/// Shared prefab-editing decisions for obstacle/platform/decoration workflows.
///
/// This keeps id/revision/form projection rules out of the page shell while
/// still letting the page own Flutter controllers and session commits.
class PrefabEditorPrefabController {
  const PrefabEditorPrefabController();

  AtlasSliceDef? findSliceById({
    required List<AtlasSliceDef> slices,
    required String? sliceId,
  }) {
    if (sliceId == null) {
      return null;
    }
    for (final slice in slices) {
      if (slice.id == sliceId) {
        return slice;
      }
    }
    return null;
  }

  PrefabDef? editingPrefabForForm({
    required PrefabData data,
    required PrefabFormState form,
  }) {
    final key = form.editingPrefabKey?.trim();
    if (key == null || key.isEmpty) {
      return null;
    }
    for (final prefab in data.prefabs) {
      if (prefab.prefabKey == key) {
        return prefab;
      }
    }
    return null;
  }

  PrefabEditorDecision<PrefabUpsertIdentity> resolveUpsertIdentity({
    required PrefabData data,
    required PrefabEditorDataReducer reducer,
    required PrefabFormState form,
  }) {
    final id = form.prefabIdController.text.trim();
    if (id.isEmpty) {
      return const PrefabEditorDecision.error('Prefab id is required.');
    }
    if (form.selectedKind == PrefabKind.unknown) {
      return const PrefabEditorDecision.error(
        'Prefab kind must be obstacle, platform, or decoration.',
      );
    }

    final existingPrefab = _findExistingPrefabForUpsert(
      data: data,
      id: id,
      form: form,
    );
    if (_hasIdCollisionForUpsert(
      data: data,
      id: id,
      existingPrefab: existingPrefab,
    )) {
      return PrefabEditorDecision.error('Prefab id "$id" already exists.');
    }

    final existingKey = existingPrefab?.prefabKey;
    return PrefabEditorDecision.success(
      PrefabUpsertIdentity(
        id: id,
        existingPrefab: existingPrefab,
        prefabKey: existingKey?.isNotEmpty == true
            ? existingKey!
            : reducer.allocatePrefabKeyForId(data, id),
      ),
    );
  }

  PrefabEditorDecision<PrefabDef> buildUpsertPrefab({
    required PrefabEditorDataReducer reducer,
    required PrefabFormState form,
    required PrefabUpsertIdentity identity,
    required PrefabVisualSource visualSource,
  }) {
    final anchorValues = form.tryParseAnchorValues();
    if (anchorValues == null) {
      return const PrefabEditorDecision.error(
        'Anchor fields must be valid integers.',
      );
    }

    List<PrefabColliderDef> nextColliders = const <PrefabColliderDef>[];
    if (form.selectedKind != PrefabKind.decoration) {
      final colliders = form.tryParseColliderDrafts();
      if (colliders == null) {
        return const PrefabEditorDecision.error(
          'Anchor/collider fields must be valid integers.',
        );
      }
      nextColliders = colliders;
    }

    final normalizedTags = reducer.normalizedTags(
      form.tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
    );

    var nextPrefab = PrefabDef(
      prefabKey: identity.prefabKey,
      id: identity.id,
      revision: identity.existingPrefab?.revision ?? 1,
      status: identity.existingPrefab?.status ?? PrefabStatus.active,
      kind: form.selectedKind,
      visualSource: visualSource,
      anchorXPx: anchorValues.anchorX,
      anchorYPx: anchorValues.anchorY,
      colliders: nextColliders,
      tags: normalizedTags,
    );

    final existingPrefab = identity.existingPrefab;
    if (existingPrefab != null &&
        reducer.didPrefabPayloadChange(existingPrefab, nextPrefab)) {
      nextPrefab = nextPrefab.copyWith(revision: existingPrefab.revision + 1);
    }
    return PrefabEditorDecision.success(nextPrefab);
  }

  PrefabFormLoadProjection projectPrefabLoad({
    required PrefabDef prefab,
    required PrefabEditorDataReducer reducer,
    required TileModuleDef? backingModule,
  }) {
    final collider = prefab.colliders.isEmpty
        ? const PrefabColliderDef(offsetX: 0, offsetY: 0, width: 16, height: 16)
        : prefab.colliders.first;
    final selectedKind = switch (prefab.kind) {
      PrefabKind.platform => PrefabKind.platform,
      PrefabKind.decoration => PrefabKind.decoration,
      _ => PrefabKind.obstacle,
    };
    final autoManagePlatformModule = selectedKind == PrefabKind.platform
        ? prefab.usesPlatformModule
              ? reducer.isAutoManagedModuleForPrefab(
                  prefabKey: prefab.prefabKey,
                  moduleId: prefab.moduleId,
                )
              : true
        : true;

    return PrefabFormLoadProjection(
      formSnapshot: PrefabFormDraftSnapshot(
        prefabId: prefab.id,
        anchorX: prefab.anchorXPx.toString(),
        anchorY: prefab.anchorYPx.toString(),
        colliderOffsetX: collider.offsetX.toString(),
        colliderOffsetY: collider.offsetY.toString(),
        colliderWidth: collider.width.toString(),
        colliderHeight: collider.height.toString(),
        colliders: List<PrefabColliderDef>.unmodifiable(prefab.colliders),
        selectedColliderIndex: prefab.colliders.isEmpty ? null : 0,
        tags: prefab.tags.join(', '),
        autoManagePlatformModule: autoManagePlatformModule,
        selectedKind: selectedKind,
        editingPrefabKey: prefab.prefabKey,
      ),
      selectedPrefabSliceId: prefab.usesAtlasSlice ? prefab.sliceId : null,
      selectedPrefabPlatformModuleId: prefab.usesPlatformModule
          ? prefab.moduleId
          : null,
      selectedModuleId: prefab.usesPlatformModule ? prefab.moduleId : null,
      moduleTileSizeText: backingModule?.tileSize.toString(),
    );
  }

  PrefabEditorDecision<PrefabDef> buildDuplicate({
    required PrefabData data,
    required PrefabEditorDataReducer reducer,
    required PrefabFormState form,
    required PrefabDef source,
  }) {
    final requestedId = form.prefabIdController.text.trim();
    if (requestedId.isEmpty) {
      return const PrefabEditorDecision.error(
        'Set a new Prefab ID before duplicating.',
      );
    }
    if (requestedId == source.id) {
      return const PrefabEditorDecision.error(
        'Duplicate Prefab ID must differ from the source prefab id.',
      );
    }
    if (data.prefabs.any((prefab) => prefab.id == requestedId)) {
      return PrefabEditorDecision.error(
        'Prefab id "$requestedId" already exists.',
      );
    }

    return PrefabEditorDecision.success(
      source.copyWith(
        prefabKey: reducer.allocatePrefabKeyForId(data, requestedId),
        id: requestedId,
        revision: 1,
        status: PrefabStatus.active,
      ),
    );
  }

  PrefabDef? _findExistingPrefabForUpsert({
    required PrefabData data,
    required String id,
    required PrefabFormState form,
  }) {
    final editingKey = form.editingPrefabKey?.trim();
    if (editingKey != null && editingKey.isNotEmpty) {
      for (final prefab in data.prefabs) {
        if (prefab.prefabKey == editingKey &&
            prefab.kind == form.selectedKind) {
          return prefab;
        }
      }
    }
    for (final prefab in data.prefabs) {
      if (prefab.id == id) {
        return prefab;
      }
    }
    return null;
  }

  bool _hasIdCollisionForUpsert({
    required PrefabData data,
    required String id,
    required PrefabDef? existingPrefab,
  }) {
    for (final prefab in data.prefabs) {
      if (prefab.id != id) {
        continue;
      }
      if (existingPrefab == null) {
        return true;
      }
      if (prefab.prefabKey != existingPrefab.prefabKey) {
        return true;
      }
    }
    return false;
  }
}

@immutable
class PrefabEditorDecision<T> {
  const PrefabEditorDecision.success(this.value) : error = null;

  const PrefabEditorDecision.error(this.error) : value = null;

  final T? value;
  final String? error;

  bool get isSuccess => value != null;
}

@immutable
class PrefabUpsertIdentity {
  const PrefabUpsertIdentity({
    required this.id,
    required this.existingPrefab,
    required this.prefabKey,
  });

  final String id;
  final PrefabDef? existingPrefab;
  final String prefabKey;
}

@immutable
class PrefabFormLoadProjection {
  const PrefabFormLoadProjection({
    required this.formSnapshot,
    required this.selectedPrefabSliceId,
    required this.selectedPrefabPlatformModuleId,
    required this.selectedModuleId,
    required this.moduleTileSizeText,
  });

  final PrefabFormDraftSnapshot formSnapshot;
  final String? selectedPrefabSliceId;
  final String? selectedPrefabPlatformModuleId;
  final String? selectedModuleId;
  final String? moduleTileSizeText;
}
