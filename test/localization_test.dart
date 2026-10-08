import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_gps_pro/l10n/l10n.dart';
import 'package:fake_gps_pro/l10n/languages.dart';
import 'package:fake_gps_pro/main.dart';
import 'package:fake_gps_pro/models/location_message.dart';
import 'package:fake_gps_pro/providers/language_provider.dart';
import 'package:fake_gps_pro/providers/location_provider.dart';
import 'package:fake_gps_pro/screens/home_screen.dart';
import 'package:fake_gps_pro/screens/language_screen.dart';
import 'package:fake_gps_pro/services/mock_location_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MockLocationService.channel,
      (call) async {
        if (call.method == 'getStatus') {
          return {
            'developerEnabled': true,
            'mockAppSelected': true,
            'locationEnabled': true,
            'locationPermissionGranted': true,
            'isMocking': true,
            'hasProviders': true,
            'latitude': -6.2,
            'longitude': 106.8,
          };
        }
        return true;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MockLocationService.channel,
      null,
    ),
  );

  test(
    'every listed language has every message and matching ICU placeholders',
    () {
      final base =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final keys = base.keys.where((key) => !key.startsWith('@')).toSet();
      expect(appLanguages, hasLength(80));
      expect(
        AppLocalizations.supportedLocales.toSet(),
        appLanguages.map((x) => x.locale).toSet(),
      );
      for (final language in appLanguages) {
        final catalog =
            jsonDecode(
                  File(
                    'lib/l10n/app_${language.locale.toString()}.arb',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(
          catalog.keys.where((key) => !key.startsWith('@')).toSet(),
          keys,
          reason: language.englishName,
        );
        for (final key in keys) {
          final value = catalog[key] as String;
          expect(value.trim(), isNotEmpty, reason: '${language.locale}.$key');
          expect(
            RegExp(r'ZXQ|\[\[|\]\]|\n').hasMatch(value),
            isFalse,
            reason: '${language.locale}.$key',
          );
          Set<String> placeholders(String text) => RegExp(
            r'\{\w+\}',
          ).allMatches(text).map((match) => match[0]!).toSet();
          expect(
            placeholders(value),
            placeholders(base[key] as String),
            reason: '${language.locale}.$key',
          );
        }
      }
    },
  );

  test(
    'device locale resolves Chinese scripts, aliases, preferred languages and fallback',
    () {
      Locale resolve(List<Locale> locales) =>
          resolveAppLocale(locales, AppLocalizations.supportedLocales);
      expect(
        resolve([const Locale('zh', 'TW')]),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        resolve([const Locale('zh', 'HK')]),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        resolve([
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'TW',
          ),
        ]),
        const Locale('zh'),
      );
      expect(resolve([const Locale('tl')]), const Locale('fil'));
      expect(resolve([const Locale('no')]), const Locale('nb'));
      expect(resolve([const Locale('gsw')]), const Locale('de'));
      expect(
        resolve([const Locale('xx'), const Locale('fr', 'CA')]),
        const Locale('fr'),
      );
      expect(resolve([const Locale('xx')]), const Locale('en'));
      expect(resolve([]), const Locale('en'));
    },
  );

  test(
    'language preference survives restart and system option clears it',
    () async {
      final first = ProviderContainer();
      await first.read(languageProvider.future);
      await first.read(languageProvider.notifier).select(const Locale('ar'));
      first.dispose();
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      expect(await restarted.read(languageProvider.future), const Locale('ar'));
      await restarted.read(languageProvider.notifier).select(null);
      expect(restarted.read(languageProvider).valueOrNull, isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          appLanguagePreferenceKey,
        ),
        isFalse,
      );
    },
  );

  test('invalid stored locale falls back to device language', () async {
    SharedPreferences.setMockInitialValues({appLanguagePreferenceKey: 'xx-YY'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(languageProvider.future), isNull);
  });

  test(
    'localized coordinate entry preserves signed values and decimal separators',
    () {
      expect(
        LocationNotifier.parseCoordinates('−٦٫٢', '١٠٦٫٨'),
        const LatLng(-6.2, 106.8),
      );
      expect(
        LocationNotifier.parseCoordinates('-۶,۲', '۱۰۶,۸'),
        const LatLng(-6.2, 106.8),
      );
      expect(
        LocationNotifier.parseCoordinates('−६.२', '१०६.८'),
        const LatLng(-6.2, 106.8),
      );
      expect(LocationNotifier.parseCoordinates('९१', '0'), isNull);
    },
  );

  test('messages and date formatting work in all 80 locales', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final strings = await AppLocalizations.delegate.load(locale);
      final material = await GlobalMaterialLocalizations.delegate.load(locale);
      for (final message in LocationMessage.values) {
        expect(
          message.localize(strings),
          isNotEmpty,
          reason: '$locale.$message',
        );
      }
      expect(strings.activeCoordinates('-6.2, 106.8'), contains('-6.2, 106.8'));
      expect(strings.routePoints(2), contains('2'));
      expect(
        formatHistoryTimestamp(material, DateTime(2026, 9, 17, 14, 30)),
        isNotEmpty,
      );
    }
  });

  for (final language in appLanguages) {
    testWidgets(
      '${language.locale}: home, guide and library fit small screens',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = await AppLocalizations.delegate.load(language.locale);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: appTheme(Brightness.light),
              locale: language.locale,
              localizationsDelegates: appLocalizationDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: HomeScreen(
                mapBuilder: (context, state) =>
                    const SizedBox(key: ValueKey('test_map')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final homeContext = tester.element(find.byType(HomeScreen));
        final rtl = [
          'ar',
          'fa',
          'he',
          'ps',
          'ug',
          'ur',
        ].contains(language.locale.languageCode);
        expect(
          Directionality.of(homeContext),
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        final latitude = tester.widget<TextField>(
          find.widgetWithText(TextField, strings.latitude),
        );
        expect(latitude.textDirection, TextDirection.ltr);
        // The stop action must remain discoverable in every language.
        expect(find.text(strings.stopMock), findsOneWidget);
        await tester.tap(find.byTooltip(strings.guideAndSettings));
        await tester.pumpAndSettle();
        expect(find.text(strings.setupDevice), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text(strings.setupDevice))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.searchPlaces));
        await tester.pumpAndSettle();
        expect(find.text(strings.exploreLocations), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'language picker updates app without restarting the location provider',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(languageProvider.future);
      final location = container.read(locationProvider.notifier);
      location.setPosition(const LatLng(12, 34));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp(
                locale: ref.watch(languageProvider).valueOrNull,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: appLocalizationDelegates,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageScreen(),
                        ),
                      ),
                      child: Text(context.l10n.language),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Arabic');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-ar')));
      await tester.pumpAndSettle();
      expect(container.read(languageProvider).valueOrNull, const Locale('ar'));
      expect(
        identical(container.read(locationProvider.notifier), location),
        isTrue,
      );
      expect(
        container.read(locationProvider).currentPosition,
        const LatLng(12, 34),
      );
      expect(find.text('Language'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
