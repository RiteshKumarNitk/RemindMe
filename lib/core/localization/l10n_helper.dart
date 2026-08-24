import 'dart:ui';

import 'generated/app_localizations.dart';

/// Builds [AppLocalizations] for a locale code without a BuildContext.
AppLocalizations l10nFor(String localeCode) =>
    lookupAppLocalizations(Locale(localeCode));
