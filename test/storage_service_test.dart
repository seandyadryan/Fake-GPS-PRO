import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_gps_pro/models/location_history.dart';
import 'package:fake_gps_pro/models/saved_location.dart';
import 'package:fake_gps_pro/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saved locations persist and can be deleted without removing others',
    () async {
      for (final id in ['office', 'home']) {
        await StorageService.saveLocation(
          SavedLocation(
            id: id,
            name: id,
            latitude: -6.2,
            longitude: 106.8,
            createdAt: DateTime(2026),
          ),
        );
      }
      expect(await StorageService.getSavedLocations(), hasLength(2));
      await StorageService.deleteLocation('office');
      final saved = await StorageService.getSavedLocations();
      expect(saved.single.name, 'home');
      expect(saved.single.latitude, -6.2);
    },
  );

  test('history keeps the latest 50 locations in newest-first order', () async {
    for (var i = 0; i < 55; i++) {
      await StorageService.addHistory(
        LocationHistory(
          id: '$i',
          latitude: -6.2,
          longitude: 106.8,
          address: '$i',
          timestamp: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );
    }
    final history = await StorageService.getHistory();
    expect(history, hasLength(50));
    expect(history.first.id, '54');
    expect(history.last.id, '5');
  });
}
