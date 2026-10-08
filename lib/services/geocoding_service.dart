import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

class GeocodingService {
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org';
  static const _googleGeocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  static bool get _hasGoogleKey =>
      AppConfig.googleMapsApiKey.isNotEmpty &&
      AppConfig.googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY';

  static Future<List<GeocodingResult>> search(
    String query, {
    String languageCode = 'en',
  }) async {
    if (_hasGoogleKey) {
      try {
        final uri = Uri.parse(
          '$_googleGeocodeUrl?address=${Uri.encodeComponent(query)}&key=${AppConfig.googleMapsApiKey}&language=$languageCode',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['status'] == 'OK' && data['results'] is List) {
            final list = data['results'] as List;
            return list.map((e) {
              final loc = e['geometry']['location'];
              return GeocodingResult(
                latitude: (loc['lat'] as num).toDouble(),
                longitude: (loc['lng'] as num).toDouble(),
                displayName: e['formatted_address'] ?? '',
              );
            }).toList();
          }
        }
      } catch (_) {
        // Fallback to Nominatim
      }
    }

    final uri = Uri.parse(
      '$_nominatimUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
    );
    final response = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'FakeGPSPro/1.0',
            'Accept-Language': languageCode,
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Search service returned ${response.statusCode}');
    }
    final List data = jsonDecode(response.body);
    return data
        .map(
          (e) => GeocodingResult(
            latitude: double.parse(e['lat']),
            longitude: double.parse(e['lon']),
            displayName: e['display_name'] ?? '',
          ),
        )
        .toList();
  }

  static Future<String> reverse(double lat, double lng) async {
    if (_hasGoogleKey) {
      try {
        final uri = Uri.parse(
          '$_googleGeocodeUrl?latlng=$lat,$lng&key=${AppConfig.googleMapsApiKey}',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['status'] == 'OK' &&
              data['results'] is List &&
              (data['results'] as List).isNotEmpty) {
            return data['results'][0]['formatted_address'] ?? '$lat, $lng';
          }
        }
      } catch (_) {
        // Fallback to Nominatim
      }
    }

    final uri = Uri.parse(
      '$_nominatimUrl/reverse?lat=$lat&lon=$lng&format=json',
    );
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'FakeGPSPro/1.0'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return '$lat, $lng';
      final data = jsonDecode(response.body);
      return data['display_name'] ?? '$lat, $lng';
    } catch (_) {
      return '$lat, $lng';
    }
  }
}
