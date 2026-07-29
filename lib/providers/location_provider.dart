import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/mock_location_service.dart';
import '../services/storage_service.dart';
import '../services/geocoding_service.dart';
import '../models/location_history.dart';

class LocationState {
  final LatLng currentPosition;
  final bool isMocking;
  final bool isLoading;
  final bool isSimulating;
  final List<LatLng> simulationPath;

  LocationState({
    this.currentPosition = const LatLng(-6.2088, 106.8456),
    this.isMocking = false,
    this.isLoading = false,
    this.isSimulating = false,
    this.simulationPath = const [],
  });

  LocationState copyWith({
    LatLng? currentPosition,
    bool? isMocking,
    bool? isLoading,
    bool? isSimulating,
    List<LatLng>? simulationPath,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isMocking: isMocking ?? this.isMocking,
      isLoading: isLoading ?? this.isLoading,
      isSimulating: isSimulating ?? this.isSimulating,
      simulationPath: simulationPath ?? this.simulationPath,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  Timer? _simulationTimer;
  int _simulationIndex = 0;

  LocationNotifier() : super(LocationState());

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void setPosition(LatLng pos) {
    state = state.copyWith(currentPosition: pos);
  }

  Future<void> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      state = state.copyWith(
        currentPosition: LatLng(position.latitude, position.longitude),
      );
    } catch (_) {}
  }

  void updateCoords(String latText, String lngText) {
    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
    state = state.copyWith(currentPosition: LatLng(lat, lng));
  }

  Future<String> toggleMockMode(String latText, String lngText) async {
    if (state.isMocking) {
      final success = await MockLocationService.disableMockMode();
      if (success) {
        state = state.copyWith(isMocking: false);
        _stopSimulation();
        return 'Mock location disabled';
      }
      return 'Failed to disable';
    } else {
      final lat = double.tryParse(latText);
      final lng = double.tryParse(lngText);
      if (lat == null || lng == null) return 'Enter valid coordinates first';

      state = state.copyWith(isLoading: true);
      final success = await MockLocationService.enableMockMode(lat, lng);
      if (success) {
        state = state.copyWith(
          isMocking: true,
          isLoading: false,
          currentPosition: LatLng(lat, lng),
        );
        _addToHistory(lat, lng);
        return 'Mock location activated';
      }
      state = state.copyWith(isLoading: false);
      return 'Failed to activate.\nGo to Settings → Developer Options → Select mock location app → choose Fake GPS PRO';
    }
  }

  void addSimulationPoint() {
    state = state.copyWith(
      simulationPath: [...state.simulationPath, state.currentPosition],
    );
  }

  void startSimulation() {
    if (state.simulationPath.length < 2) return;
    state = state.copyWith(isSimulating: true);
    _simulationIndex = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_simulationIndex >= state.simulationPath.length) {
        _stopSimulation();
        return;
      }
      final point = state.simulationPath[_simulationIndex];
      state = state.copyWith(currentPosition: point);
      if (state.isMocking) {
        await MockLocationService.setMockLocation(point.latitude, point.longitude);
      }
      _simulationIndex++;
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    state = state.copyWith(
      isSimulating: false,
      simulationPath: [],
    );
    _simulationIndex = 0;
  }

  Future<void> updateMockLocation() async {
    if (!state.isMocking) return;
    await MockLocationService.setMockLocation(
      state.currentPosition.latitude,
      state.currentPosition.longitude,
    );
  }

  Future<void> _addToHistory(double lat, double lng) async {
    final address = await GeocodingService.reverse(lat, lng);
    final entry = LocationHistory(
      id: const Uuid().v4(),
      latitude: lat,
      longitude: lng,
      address: address,
      timestamp: DateTime.now(),
    );
    await StorageService.addHistory(entry);
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
