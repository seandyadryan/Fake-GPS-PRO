import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';

const appLanguagePreferenceKey = 'app_language';

class LanguageNotifier extends AsyncNotifier<Locale?> {
  @override
  Future<Locale?> build() async {
    final preferences = await SharedPreferences.getInstance();
    return parseSavedLocale(preferences.getString(appLanguagePreferenceKey));
  }

  Future<void> select(Locale? locale) async {
    if (locale != null && !AppLocalizations.supportedLocales.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported app language');
    }
    final preferences = await SharedPreferences.getInstance();
    final success = locale == null
        ? await preferences.remove(appLanguagePreferenceKey)
        : await preferences.setString(
            appLanguagePreferenceKey,
            locale.toLanguageTag(),
          );
    if (!success) throw StateError('Could not persist language');
    state = AsyncData(locale);
  }
}

final languageProvider = AsyncNotifierProvider<LanguageNotifier, Locale?>(
  LanguageNotifier.new,
);
