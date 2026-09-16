import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_gps_pro/main.dart';
import 'package:fake_gps_pro/screens/home_screen.dart';
import 'package:fake_gps_pro/services/mock_location_service.dart';

class BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final sdk = Platform.environment['FLUTTER_ROOT'];
      if (sdk == null) {
        throw StateError('FLUTTER_ROOT required for preview fonts');
      }
      final fonts = '$sdk/bin/cache/artifacts/material_fonts';
      final text = FontLoader('Roboto')
        ..addFont(
          File(
            '$fonts/roboto-regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$fonts/materialicons-regular.otf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await text.load();
      await icons.load();
    }
  });
  late Map<String, Object?> status;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    status = {
      'developerEnabled': true,
      'mockAppSelected': true,
      'locationEnabled': true,
      'locationPermissionGranted': true,
      'isMocking': false,
      'hasProviders': false,
    };
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      MockLocationService.channel,
      (call) async {
        if (call.method == 'getStatus') return status;
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

  Future<void> showHome(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('preview'),
            child: HomeScreen(tileProvider: BlankTiles()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('coordinate edits survive status polling', (tester) async {
    await showHome(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Latitude'),
      '-7.123456',
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('-7.123456'), findsOneWidget);
    expect(find.text('Stop mock location'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('spoof opens required setup when Developer Mode is disabled', (
    tester,
  ) async {
    status['developerEnabled'] = false;
    await showHome(tester);
    await tester.ensureVisible(find.text('Mulai spoof'));
    await tester.tap(find.text('Mulai spoof'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Siapkan perangkat'), findsOneWidget);
    expect(find.text('Aktifkan Developer Mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('saved locations update inside the open library after deletion', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'saved_locations': jsonEncode([
        {
          'id': 'one',
          'name': 'Kantor',
          'latitude': -6.2,
          'longitude': 106.8,
          'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        },
      ]),
    });
    await showHome(tester);
    await tester.tap(find.text('Cari tempat atau lokasi tersimpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tersimpan'));
    await tester.pumpAndSettle();
    expect(find.text('Kantor'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus lokasi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada lokasi tersimpan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  for (final layout in [
    ('portrait', const Size(390, 844), Brightness.light, 1.0),
    ('small', const Size(320, 568), Brightness.light, 1.0),
    ('landscape', const Size(844, 390), Brightness.light, 1.0),
    ('dark', const Size(390, 844), Brightness.dark, 1.0),
    ('large-text', const Size(390, 844), Brightness.light, 1.5),
    ('active', const Size(390, 844), Brightness.light, 1.0),
  ]) {
    testWidgets('layout ${layout.$1} has no overflow', (tester) async {
      if (layout.$1 == 'active') {
        status.addAll({
          'isMocking': true,
          'hasProviders': true,
          'latitude': -6.2088,
          'longitude': 106.8456,
        });
      }
      await showHome(
        tester,
        size: layout.$2,
        brightness: layout.$3,
        textScale: layout.$4,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/ui-preview');
          dir.createSync(recursive: true);
          File(
            '${dir.path}/${layout.$1}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await close(tester);
    });
  }

  testWidgets('search sheet fits a small screen with the keyboard open', (
    tester,
  ) async {
    await showHome(tester, size: const Size(320, 568));
    await tester.tap(find.text('Cari tempat atau lokasi tersimpan'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
