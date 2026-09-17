import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/l10n.dart';
import 'providers/language_provider.dart';
import 'services/mock_location_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FakeGPSProApp()));
}

ThemeData appTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F766E),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

class FakeGPSProApp extends ConsumerWidget {
  const FakeGPSProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp(
      title: 'Fake GPS PRO',
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: language.valueOrNull,
      localizationsDelegates: appLocalizationDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveAppLocale,
      builder: (context, child) => language.isLoading
          ? child!
          : _NativeLanguageSync(locale: language.valueOrNull, child: child!),
      home: language.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : const HomeScreen(),
    );
  }
}

/// Keep notification labels aligned with the app without restarting its service.
class _NativeLanguageSync extends StatefulWidget {
  final Locale? locale;
  final Widget child;
  const _NativeLanguageSync({required this.locale, required this.child});

  @override
  State<_NativeLanguageSync> createState() => _NativeLanguageSyncState();
}

class _NativeLanguageSyncState extends State<_NativeLanguageSync> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _NativeLanguageSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale) _sync();
  }

  Future<void> _sync() async {
    try {
      await MockLocationService.channel.invokeMethod('setAppLanguage', {
        'languageTag': widget.locale?.toLanguageTag(),
      });
    } on MissingPluginException {
      // The mock-location backend is Android only.
    } on PlatformException {
      // UI translations still work; synchronize again on the next app launch.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
