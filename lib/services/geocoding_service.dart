import 'dart:convert';
import 'package:http/http.dart' as http;

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
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  static Future<List<GeocodingResult>> search(String query) async {
    final uri = Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
    final response = await http.get(uri, headers: {
      'User-Agent': 'FakeGPSPro/1.0',
    });
    if (response.statusCode != 200) return [];
    final List data = jsonDecode(response.body);
    return data.map((e) => GeocodingResult(
      latitude: double.parse(e['lat']),
      longitude: double.parse(e['lon']),
      displayName: e['display_name'] ?? '',
    )).toList();
  }

  static Future<String> reverse(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/reverse?lat=$lat&lon=$lng&format=json');
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'FakeGPSPro/1.0',
      });
      if (response.statusCode != 200) return '$lat, $lng';
      final data = jsonDecode(response.body);
      return data['display_name'] ?? '$lat, $lng';
    } catch (_) {
      return '$lat, $lng';
    }
  }
}
