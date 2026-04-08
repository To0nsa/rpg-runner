import 'package:flutter/widgets.dart';

import '../../../../prefabs/models/models.dart';

/// Common coordinator callback contracts for the prefab editor page shell.
///
/// Keeping these aliases in one file makes coordinator constructors easier to
/// scan and avoids repeating long anonymous function types across the feature
/// seams.
typedef PrefabEditorStateSetter = void Function(VoidCallback callback);

typedef PrefabEditorLocalDraftMutation = void Function(VoidCallback callback);

typedef PrefabEditorCommitDataChange =
    void Function({
      required PrefabData nextData,
      required String statusMessage,
      VoidCallback? beforeSync,
    });
