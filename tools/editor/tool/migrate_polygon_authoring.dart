import 'dart:io';

import 'package:runner_editor/src/migration/polygon_authoring_migration_command.dart';

void main(List<String> arguments) {
  exitCode = PolygonAuthoringMigrationCommand.run(arguments);
}
