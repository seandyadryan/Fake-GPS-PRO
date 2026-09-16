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
  final String? error;

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
    String? error,
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
    final lat = double.tryParse(latText.trim());
    final lng = double.tryParse(lngText.trim());
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

  void setPosition(LatLng pos) {
    state = state.copyWith(currentPosition: pos);
  }

  Future<String?> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Izin lokasi diblokir. Buka pengaturan aplikasi dan izinkan Lokasi.';
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return 'Izin lokasi diperlukan untuk menjalankan spoof.';
    }
    return null;
  }

  Future<String?> getCurrentLocation() async {
    if (state.isMocking || state.setup?.hasProviders == true) {
      return 'Stop mock location dahulu untuk mengambil lokasi perangkat.';
    }
    try {
      final error = await requestLocationPermission();
      if (error != null) return error;
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Aktifkan layanan lokasi perangkat.';
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (position.isMocked) {
        return 'GPS masih mengembalikan lokasi mock terakhir. Tunggu sebentar lalu coba lagi.';
      }
      if (mounted && !state.isMocking) {
        state = state.copyWith(
          currentPosition: LatLng(position.latitude, position.longitude),
        );
      }
      return null;
    } catch (_) {
      return 'Lokasi belum didapat. Pastikan GPS aktif lalu coba lagi.';
    }
  }

  Future<String> startMock(String latText, String lngText) async {
    if (state.isLoading) return 'Tunggu proses sebelumnya selesai.';
    final pos = parseCoordinates(latText, lngText);
    if (pos == null) {
      return 'Koordinat tidak valid. Latitude −90…90, longitude −180…180.';
    }
    _operationVersion++;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final setup = await MockLocationService.getStatus();
      if (!mounted) return '';
      state = state.copyWith(setup: setup);
      if (!setup.supported) return 'Spoof lokasi tersedia di Android saja.';
      if (!setup.developerEnabled) {
        return 'Aktifkan Developer Mode terlebih dahulu.';
      }
      if (!setup.mockAppSelected) {
        return 'Pilih Fake GPS PRO sebagai aplikasi mock location.';
      }
      if (!setup.locationEnabled) {
        return 'Aktifkan layanan lokasi perangkat terlebih dahulu.';
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
        throw PlatformException(
          code: 'START_FAILED',
          message: 'Android menolak spoof lokasi.',
        );
      }
      if (!mounted) return '';
      stopSimulation();
      state = state.copyWith(
        isMocking: true,
        currentPosition: pos,
        activePosition: pos,
      );
      await _addToHistory(pos);
      await refreshStatus();
      return 'Mock location aktif.';
    } catch (e) {
      await refreshStatus();
      if (mounted) state = state.copyWith(error: _message(e));
      return _message(e);
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<String> stopMock() async {
    if (state.isLoading) return 'Tunggu proses sebelumnya selesai.';
    _operationVersion++;
    stopSimulation();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (!await MockLocationService.disableMockMode()) {
        throw PlatformException(
          code: 'STOP_FAILED',
          message: 'Mock location belum berhasil dihentikan.',
        );
      }
      if (!mounted) return '';
      state = state.copyWith(isMocking: false);
      await refreshStatus();
      return 'Mock location dihentikan. Menunggu pembaruan lokasi asli dari GPS.';
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

  String? startSimulation() {
    if (state.isLoading || state.isSimulating) return null;
    if (!state.isMocking) return 'Mulai spoof sebelum menjalankan rute.';
    if (state.simulationPath.length < 2) {
      return 'Tambahkan minimal 2 titik rute.';
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
          message: 'Pembaruan lokasi rute gagal.',
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
        state = state.copyWith(
          error: 'Spoof aktif, tetapi riwayat gagal disimpan.',
        );
      }
    }
  }

  String _message(Object e) => e is PlatformException
      ? e.message ?? 'Operasi Android gagal (${e.code}).'
      : 'Operasi lokasi gagal. Coba lagi.';
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) {
    return LocationNotifier(
      onHistoryChanged: () => ref.invalidate(storageProvider),
    );
  },
);
