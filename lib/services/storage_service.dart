import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_location.dart';
import '../models/location_history.dart';

class StorageService {
  static const _savedKey = 'saved_locations';
  static const _historyKey = 'location_history';

  static Future<List<SavedLocation>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_savedKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => SavedLocation.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveLocation(SavedLocation location) async {
    final list = await getSavedLocations();
    list.add(location);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> deleteLocation(String id) async {
    final list = await getSavedLocations();
    list.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<List<LocationHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_historyKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => LocationHistory.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> addHistory(LocationHistory entry) async {
    final list = await getHistory();
    list.insert(0, entry);
    if (list.length > 50) list.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
