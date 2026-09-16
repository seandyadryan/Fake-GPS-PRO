import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_gps_pro/providers/location_provider.dart';
import 'package:fake_gps_pro/services/mock_location_service.dart';
import 'package:fake_gps_pro/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocationNotifier notifier;
  late Map<String, Object?> status;
  late List<MethodCall> calls;
  bool failStart = false;
  bool failStop = false;
  Completer<bool>? startResult;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    status = {
      'developerEnabled': true,
      'mockAppSelected': true,
      'locationEnabled': true,
      'locationPermissionGranted': true,
      'isMocking': false,
      'hasProviders': false,
      'latitude': -6.2,
      'longitude': 106.8,
    };
    calls = [];
    failStart = false;
    failStop = false;
    startResult = null;
    messenger.setMockMethodCallHandler(MockLocationService.channel, (
      call,
    ) async {
      calls.add(call);
      switch (call.method) {
        case 'getStatus':
          return Map.of(status);
        case 'enableMockMode':
          if (failStart) {
            throw PlatformException(
              code: 'SERVICE_ERROR',
              message: 'Android rejected provider',
            );
          }
          if (startResult != null) await startResult!.future;
          status['isMocking'] = true;
          status['hasProviders'] = true;
          status['latitude'] = call.arguments['latitude'];
          status['longitude'] = call.arguments['longitude'];
          return true;
        case 'disableMockMode':
          if (failStop) {
            throw PlatformException(
              code: 'SERVICE_ERROR',
              message: 'Cleanup failed',
            );
          }
          status['isMocking'] = false;
          status['hasProviders'] = false;
          return true;
        case 'setMockLocation':
          status['latitude'] = call.arguments['latitude'];
          status['longitude'] = call.arguments['longitude'];
          return true;
      }
      return true;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => <int, int>{17: 1},
    );
    notifier = LocationNotifier();
  });

  tearDown(() {
    notifier.dispose();
    messenger.setMockMethodCallHandler(MockLocationService.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      null,
    );
  });

  test(
    'rejects non-finite and out-of-range coordinates before invoking Android',
    () async {
      for (final coords in [
        ('NaN', '1'),
        ('1', 'Infinity'),
        ('91', '0'),
        ('0', '-181'),
        ('', '0'),
      ]) {
        expect(
          await notifier.startMock(coords.$1, coords.$2),
          contains('Koordinat tidak valid'),
        );
      }
      expect(calls, isEmpty);
      expect(
        LocationNotifier.parseCoordinates('-90', '180'),
        const LatLng(-90, 180),
      );
    },
  );

  for (final flag in [
    'developerEnabled',
    'mockAppSelected',
    'locationEnabled',
  ]) {
    test('blocks spoof when $flag is disabled', () async {
      status[flag] = false;
      await notifier.startMock('-6.2', '106.8');
      expect(calls.where((call) => call.method == 'enableMockMode'), isEmpty);
      expect(notifier.state.isMocking, isFalse);
      expect(notifier.state.isLoading, isFalse);
    });
  }

  test('native errors never report successful spoof or add history', () async {
    failStart = true;
    expect(
      await notifier.startMock('-6.2', '106.8'),
      contains('Android rejected provider'),
    );
    expect(notifier.state.isMocking, isFalse);
    expect(notifier.state.isLoading, isFalse);
    expect(await StorageService.getHistory(), isEmpty);
  });

  test(
    'waits for native acknowledgment and ignores duplicate starts',
    () async {
      startResult = Completer<bool>();
      final operation = notifier.startMock('-6.2', '106.8');
      while (!calls.any((call) => call.method == 'enableMockMode')) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(notifier.state.isMocking, isFalse);
      expect(notifier.state.isLoading, isTrue);
      await notifier.startMock('10', '20');
      expect(
        calls.where((call) => call.method == 'enableMockMode'),
        hasLength(1),
      );
      startResult!.complete(true);
      await operation;
      expect(notifier.state.isMocking, isTrue);
      expect(await StorageService.getHistory(), hasLength(1));
    },
  );

  test('failed stop retains native running state and exposes error', () async {
    await notifier.startMock('-6.2', '106.8');
    failStop = true;
    expect(await notifier.stopMock(), contains('Cleanup failed'));
    expect(notifier.state.isMocking, isTrue);
    expect(notifier.state.isLoading, isFalse);
  });

  test(
    'sync restores running service and observes notification stop',
    () async {
      status['isMocking'] = true;
      await notifier.refreshStatus();
      expect(notifier.state.isMocking, isTrue);
      expect(notifier.state.currentPosition, const LatLng(-6.2, 106.8));
      status['isMocking'] = false;
      await notifier.refreshStatus();
      expect(notifier.state.isMocking, isFalse);
    },
  );

  testWidgets('stop route cancels future points while spoof stays active', (
    tester,
  ) async {
    status['isMocking'] = true;
    await notifier.refreshStatus();
    notifier.addSimulationPoint();
    notifier.setPosition(const LatLng(1, 2));
    notifier.addSimulationPoint();
    notifier.startSimulation();
    await tester.pump();
    expect(
      calls.where((call) => call.method == 'setMockLocation'),
      hasLength(1),
    );
    notifier.stopSimulation();
    await tester.pump(const Duration(seconds: 10));
    expect(
      calls.where((call) => call.method == 'setMockLocation'),
      hasLength(1),
    );
    expect(notifier.state.isMocking, isTrue);
    expect(notifier.state.isSimulating, isFalse);
    expect(notifier.state.simulationPath, hasLength(2));
  });

  testWidgets('stop mock cancels route and native service', (tester) async {
    status['isMocking'] = true;
    await notifier.refreshStatus();
    notifier.addSimulationPoint();
    notifier.setPosition(const LatLng(1, 2));
    notifier.addSimulationPoint();
    notifier.startSimulation();
    await tester.pump();
    await notifier.stopMock();
    await tester.pump(const Duration(seconds: 10));
    expect(
      calls.where((call) => call.method == 'setMockLocation'),
      hasLength(1),
    );
    expect(
      calls.where((call) => call.method == 'disableMockMode'),
      hasLength(1),
    );
    expect(notifier.state.isMocking, isFalse);
    expect(notifier.state.isSimulating, isFalse);
  });

  test('route requires active spoof', () {
    notifier.addSimulationPoint();
    notifier.addSimulationPoint();
    expect(notifier.startSimulation(), contains('Mulai spoof'));
    expect(calls.where((call) => call.method == 'setMockLocation'), isEmpty);
  });
}
