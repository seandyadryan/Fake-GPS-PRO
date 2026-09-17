import '../models/location_message.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:uuid/uuid.dart';
import '../services/mock_location_service.dart';
import '../services/storage_service.dart';
import '../models/location_history.dart';
import 'storage_provider.dart';

class LocationState {
  final LatLng currentPosition;
  final LatLng? activePosition;
  final bool isMocking;
  final bool isLoading;
  final bool isSimulating;
  final List<LatLng> simulationPath;
  final MockStatus? setup;
  final LocationMessage? error;

  const LocationState({
    this.currentPosition = const LatLng(-6.2088, 106.8456),
    this.activePosition,
    this.isMocking = false,
    this.isLoading = false,
    this.isSimulating = false,
    this.simulationPath = const [],
    this.setup,
    this.error,
  });

  LocationState copyWith({
    LatLng? currentPosition,
    LatLng? activePosition,
    bool? isMocking,
    bool? isLoading,
    bool? isSimulating,
    List<LatLng>? simulationPath,
    MockStatus? setup,
    LocationMessage? error,
    bool clearError = false,
  }) => LocationState(
    currentPosition: currentPosition ?? this.currentPosition,
    activePosition: activePosition ?? this.activePosition,
    isMocking: isMocking ?? this.isMocking,
    isLoading: isLoading ?? this.isLoading,
    isSimulating: isSimulating ?? this.isSimulating,
    simulationPath: simulationPath ?? this.simulationPath,
    setup: setup ?? this.setup,
    error: clearError ? null : error ?? this.error,
  );
}

class LocationNotifier extends StateNotifier<LocationState> {
  Timer? _simulationTimer;
  Timer? _statusTimer;
  bool _refreshing = false;
  int _operationVersion = 0;
  int _routeGeneration = 0;
  final void Function()? onHistoryChanged;

  LocationNotifier({this.onHistoryChanged}) : super(const LocationState());

  void monitorStatus() {
    unawaited(refreshStatus());
    _statusTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (!state.isLoading) unawaited(refreshStatus());
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _statusTimer?.cancel();
    _routeGeneration++;
    super.dispose();
  }

  Future<void> refreshStatus() async {
    if (_refreshing) return;
    _refreshing = true;
    final version = _operationVersion;
    try {
      final status = await MockLocationService.getStatus();
      if (!mounted || version != _operationVersion) return;
      if (!status.isMocking && state.isSimulating) stopSimulation();
      final active =
          status.isMocking &&
              status.latitude != null &&
              status.longitude != null
          ? LatLng(status.latitude!, status.longitude!)
          : null;
      state = state.copyWith(
        setup: status,
        isMocking: status.isMocking,
        activePosition: active,
        currentPosition: status.isMocking && !state.isMocking ? active : null,
        error: status.error,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(error: _message(e));
    } finally {
      _refreshing = false;
    }
  }

  static LatLng? parseCoordinates(String latText, String lngText) {
    final lat = double.tryParse(_normalizeCoordinate(latText));
    final lng = double.tryParse(_normalizeCoordinate(lngText));
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  static String _normalizeCoordinate(String text) {
    final normalized = text
        .trim()
        .replaceAll('−', '-')
        .replaceAll(',', '.')
        .replaceAll('٫', '.')
        .replaceAll(RegExp('[\u200e\u200f\u061c\u2066-\u2069]'), '');
    // Arabic-Indic, Persian and common South Asian decimal digits.
    const zeroes = [
      0x0660,
      0x06f0,
      0x0966,
      0x09e6,
      0x0a66,
      0x0ae6,
      0x0b66,
      0x0be6,
      0x0c66,
      0x0ce6,
      0x0d66,
      0x0e50,
      0x0ed0,
      0x1040,
      0xff10,
    ];
    return String.fromCharCodes(
      normalized.runes.map((rune) {
        for (final zero in zeroes) {
          if (rune >= zero && rune <= zero + 9) return 0x30 + rune - zero;
        }
        return rune;
      }),
    );
  }

  void setPosition(LatLng pos) {
    state = state.copyWith(currentPosition: pos);
  }

  Future<LocationMessage?> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationMessage.permissionBlocked;
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return LocationMessage.permissionRequired;
    }
    return null;
  }

  Future<LocationMessage?> getCurrentLocation() async {
    if (state.isMocking || state.setup?.hasProviders == true) {
      return LocationMessage.stopBeforeLocate;
    }
    try {
      final error = await requestLocationPermission();
      if (error != null) return error;
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationMessage.locationRequired;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (position.isMocked) {
        return LocationMessage.staleMockLocation;
      }
      if (mounted && !state.isMocking) {
        state = state.copyWith(
          currentPosition: LatLng(position.latitude, position.longitude),
        );
      }
      return null;
    } catch (_) {
      return LocationMessage.locationUnavailable;
    }
  }

  Future<LocationMessage?> startMock(String latText, String lngText) async {
    if (state.isLoading) return LocationMessage.operationBusy;
    final pos = parseCoordinates(latText, lngText);
    if (pos == null) {
      return LocationMessage.invalidCoordinates;
    }
    _operationVersion++;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final setup = await MockLocationService.getStatus();
      if (!mounted) return null;
      state = state.copyWith(setup: setup);
      if (!setup.supported) return LocationMessage.androidOnly;
      if (!setup.developerEnabled) {
        return LocationMessage.developerRequired;
      }
      if (!setup.mockAppSelected) {
        return LocationMessage.mockAppRequired;
      }
      if (!setup.locationEnabled) {
        return LocationMessage.locationRequired;
      }
      if (!setup.locationPermissionGranted) {
        final error = await requestLocationPermission();
        if (error != null) return error;
      }
      // Notification access is optional; declining it must not block spoofing.
      try {
        await permissions.Permission.notification.request();
      } catch (_) {}
      final success = await MockLocationService.enableMockMode(
        pos.latitude,
        pos.longitude,
      );
      if (!success) {
        throw PlatformException(code: 'START_FAILED', message: 'startFailed');
      }
      if (!mounted) return null;
      stopSimulation();
      state = state.copyWith(
        isMocking: true,
        currentPosition: pos,
        activePosition: pos,
      );
      await _addToHistory(pos);
      await refreshStatus();
      return LocationMessage.mockStarted;
    } catch (e) {
      await refreshStatus();
      if (mounted) state = state.copyWith(error: _message(e));
      return _message(e);
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<LocationMessage?> stopMock() async {
    if (state.isLoading) return LocationMessage.operationBusy;
    _operationVersion++;
    stopSimulation();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (!await MockLocationService.disableMockMode()) {
        throw PlatformException(code: 'STOP_FAILED', message: 'stopFailed');
      }
      if (!mounted) return null;
      state = state.copyWith(isMocking: false);
      await refreshStatus();
      return LocationMessage.mockStopped;
    } catch (e) {
      await refreshStatus();
      if (mounted) state = state.copyWith(error: _message(e));
      return _message(e);
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void addSimulationPoint() {
    if (state.isSimulating) return;
    state = state.copyWith(
      simulationPath: [...state.simulationPath, state.currentPosition],
    );
  }

  void clearRoute() {
    stopSimulation();
    state = state.copyWith(simulationPath: []);
  }

  LocationMessage? startSimulation() {
    if (state.isLoading || state.isSimulating) return null;
    if (!state.isMocking) return LocationMessage.routeNeedsMock;
    if (state.simulationPath.length < 2) {
      return LocationMessage.routeNeedsPoints;
    }
    final path = List<LatLng>.of(state.simulationPath);
    final generation = ++_routeGeneration;
    state = state.copyWith(isSimulating: true, clearError: true);
    unawaited(_runRoute(path, 0, generation));
    return null;
  }

  Future<void> _runRoute(List<LatLng> path, int index, int generation) async {
    if (!mounted || generation != _routeGeneration || !state.isSimulating) {
      return;
    }
    final point = path[index];
    try {
      final success = await MockLocationService.setMockLocation(
        point.latitude,
        point.longitude,
      );
      if (!mounted || generation != _routeGeneration) return;
      if (!success) {
        throw PlatformException(
          code: 'UPDATE_FAILED',
          message: 'routeUpdateFailed',
        );
      }
      state = state.copyWith(currentPosition: point, activePosition: point);
      if (index + 1 == path.length) {
        stopSimulation();
      } else {
        _simulationTimer = Timer(
          const Duration(seconds: 3),
          () => _runRoute(path, index + 1, generation),
        );
      }
    } catch (e) {
      if (!mounted || generation != _routeGeneration) return;
      stopSimulation();
      await refreshStatus();
      if (mounted) state = state.copyWith(error: _message(e));
    }
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _routeGeneration++;
    state = state.copyWith(isSimulating: false);
  }

  Future<void> _addToHistory(LatLng pos) async {
    try {
      // Recording coordinates locally keeps spoof/stop independent of network requests.
      await StorageService.addHistory(
        LocationHistory(
          id: const Uuid().v4(),
          latitude: pos.latitude,
          longitude: pos.longitude,
          address:
              '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
          timestamp: DateTime.now(),
        ),
      );
      if (mounted) onHistoryChanged?.call();
    } catch (_) {
      if (mounted) {
        state = state.copyWith(error: LocationMessage.historySaveFailed);
      }
    }
  }

  LocationMessage _message(Object error) {
    if (error is PlatformException) {
      final message = LocationMessage.fromCode(error.message);
      return message == LocationMessage.nativeError
          ? LocationMessage.fromCode(error.code)
          : message;
    }
    return LocationMessage.nativeError;
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) {
    return LocationNotifier(
      onHistoryChanged: () => ref.invalidate(storageProvider),
    );
  },
);
