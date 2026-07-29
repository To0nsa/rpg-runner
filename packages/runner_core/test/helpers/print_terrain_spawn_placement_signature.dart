import 'dart:convert';
import 'dart:io';

import '../fixtures/terrain_spawn_placement_fixture.dart';

void main() {
  stdout.writeln(jsonEncode(buildTerrainSpawnPlacementSignature()));
}
