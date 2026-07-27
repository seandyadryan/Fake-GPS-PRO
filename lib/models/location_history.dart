class LocationHistory {
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime timestamp;

  LocationHistory({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LocationHistory.fromJson(Map<String, dynamic> json) =>
      LocationHistory(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        address: json['address'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
