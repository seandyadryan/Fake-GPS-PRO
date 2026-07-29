import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../models/saved_location.dart';
import '../models/location_history.dart';

class StorageState {
  final List<SavedLocation> savedLocations;
  final List<LocationHistory> history;

  StorageState({
    this.savedLocations = const [],
    this.history = const [],
  });
}

class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier() : super(StorageState()) {
    _load();
  }

  Future<void> _load() async {
    final saved = await StorageService.getSavedLocations();
    final history = await StorageService.getHistory();
    state = StorageState(savedLocations: saved, history: history);
  }

  Future<void> saveLocation(String name, double lat, double lng) async {
    final location = SavedLocation(
      id: const Uuid().v4(),
      name: name,
      latitude: lat,
      longitude: lng,
      createdAt: DateTime.now(),
    );
    await StorageService.saveLocation(location);
    await _load();
  }

  Future<void> deleteLocation(String id) async {
    await StorageService.deleteLocation(id);
    await _load();
  }

  Future<void> addHistory(LocationHistory entry) async {
    await StorageService.addHistory(entry);
    await _load();
  }
}

final storageProvider = StateNotifierProvider<StorageNotifier, StorageState>((ref) {
  return StorageNotifier();
});
