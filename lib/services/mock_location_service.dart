import 'package:flutter/services.dart';

class MockStatus {
  final bool supported;
  final bool developerEnabled;
  final bool mockAppSelected;
  final bool locationEnabled;
  final bool locationPermissionGranted;
  final bool isMocking;
  final bool hasProviders;
  final double? latitude;
  final double? longitude;
  final String? error;

  const MockStatus({
    this.supported = true,
    this.developerEnabled = false,
    this.mockAppSelected = false,
    this.locationEnabled = false,
    this.locationPermissionGranted = false,
    this.isMocking = false,
    this.hasProviders = false,
    this.latitude,
    this.longitude,
    this.error,
  });

  bool get ready =>
      supported &&
      developerEnabled &&
      mockAppSelected &&
      locationEnabled &&
      locationPermissionGranted;

  factory MockStatus.fromMap(Map<dynamic, dynamic> map) => MockStatus(
    developerEnabled: map['developerEnabled'] == true,
    mockAppSelected: map['mockAppSelected'] == true,
    locationEnabled: map['locationEnabled'] == true,
    locationPermissionGranted: map['locationPermissionGranted'] == true,
    isMocking: map['isMocking'] == true,
    hasProviders: map['hasProviders'] == true,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    error: map['error'] as String?,
  );
}

class MockLocationService {
  static const channel = MethodChannel(
    'com.deploydulupulangnanti.fakegpspro/location',
  );

  static Future<MockStatus> getStatus() async {
    try {
      final map = await channel.invokeMapMethod('getStatus');
      if (map == null) throw PlatformException(code: 'NO_STATUS');
      return MockStatus.fromMap(map);
    } on MissingPluginException {
      return const MockStatus(supported: false);
    }
  }

  static Future<bool> setMockLocation(
    double latitude,
    double longitude,
  ) async =>
      await channel.invokeMethod<bool>('setMockLocation', {
        'latitude': latitude,
        'longitude': longitude,
      }) ??
      false;

  static Future<bool> enableMockMode(double latitude, double longitude) async =>
      await channel.invokeMethod<bool>('enableMockMode', {
        'latitude': latitude,
        'longitude': longitude,
      }) ??
      false;

  static Future<bool> disableMockMode() async =>
      await channel.invokeMethod<bool>('disableMockMode') ?? false;

  static Future<bool> openSettings(String type) async =>
      await channel.invokeMethod<bool>('openSettings', {'type': type}) ?? false;
}
