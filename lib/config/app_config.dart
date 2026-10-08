class AppConfig {
  static const String appName = 'Fake GPS PRO';
  static const String googleMapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY',
  );
}
