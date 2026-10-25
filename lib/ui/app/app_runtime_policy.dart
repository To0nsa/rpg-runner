import 'package:flutter/foundation.dart';

/// Web is a local Practice host until browser account/replay support exists.
/// Native profile/release builds must continue to require authenticated runs.
const bool developerPracticeAllowed = kIsWeb || kDebugMode;
