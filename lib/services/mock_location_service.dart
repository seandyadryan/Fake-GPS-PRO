import 'package:flutter/services.dart';

class MockLocationService {
  static const _channel = MethodChannel('com.deploydulupulangnanti.fakegpspro/location');

  static Future<bool> setMockLocation(double latitude, double longitude) async {
    try {
      final result = await _channel.invokeMethod<bool>('setMockLocation', {
        'latitude': latitude,
        'longitude': longitude,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to set mock location: ${e.message}");
      return false;
    }
  }

  static Future<bool> enableMockMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('enableMockMode');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to enable mock mode: ${e.message}");
      return false;
    }
  }

  static Future<bool> disableMockMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableMockMode');
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to disable mock mode: ${e.message}");
      return false;
    }
  }
}
