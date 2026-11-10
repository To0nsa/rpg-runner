import 'package:intl/intl.dart';

import '../l10n/app_localization.dart';

/// Locale-formatted presentation only; never use for serialized numeric values.
String formatCount(int value, {required AppLocalizations l10n}) =>
    NumberFormat.decimalPattern(l10n.localeName).format(value);
