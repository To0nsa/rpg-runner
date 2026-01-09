import '../../core/levels/level_id.dart';

extension LevelIdUi on LevelId {
  String get displayName {
    switch (this) {
      case LevelId.defaultLevel:
        return 'Default';
      case LevelId.forest:
        return 'Forest';
      case LevelId.field:
        return 'Field';
    }
  }
}

