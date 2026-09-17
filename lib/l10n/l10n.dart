import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';
export 'generated/app_localizations.dart';
export 'platform_localizations.dart';

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Handles language aliases and Chinese script/region preferences before
/// falling back to English. Unlisted device languages never show a blank UI.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  final available = supported.toList();
  for (final requested in preferred ?? <Locale>[]) {
    final language = switch (requested.languageCode) {
      'tl' => 'fil',
      'no' || 'nn' => 'nb',
      'gsw' => 'de',
      _ => requested.languageCode,
    };
    final matches = available.where(
      (locale) => locale.languageCode == language,
    );
    if (matches.isEmpty) continue;
    if (language == 'zh') {
      final traditional =
          requested.scriptCode == 'Hant' ||
          (requested.scriptCode == null &&
              ['TW', 'HK', 'MO'].contains(requested.countryCode));
      return matches.firstWhere(
        (locale) => traditional
            ? locale.scriptCode == 'Hant'
            : locale.scriptCode != 'Hant',
        orElse: () => matches.first,
      );
    }
    return matches.firstWhere(
      (locale) => locale == requested,
      orElse: () => matches.first,
    );
  }
  return const Locale('en');
}

Locale? parseSavedLocale(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.toLanguageTag() == value) return locale;
  }
  return null;
}

/// Material provides safe date data even for locales not covered by intl.
String formatHistoryTimestamp(
  MaterialLocalizations material,
  DateTime date, {
  bool alwaysUse24HourFormat = false,
}) =>
    '${material.formatCompactDate(date)} • ${material.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: alwaysUse24HourFormat)}';
