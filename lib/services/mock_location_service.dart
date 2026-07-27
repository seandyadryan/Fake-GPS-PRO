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
      return false;
    }
  }

  static Future<bool> enableMockMode(double latitude, double longitude) async {
    try {
      final result = await _channel.invokeMethod<bool>('enableMockMode', {
        'latitude': latitude,
        'longitude': longitude,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      return false;
    }
  }

  static Future<bool> disableMockMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('disableMockMode');
      return result ?? false;
    } on PlatformException catch (e) {
      return false;
    }
  }
}
