class CommunityAlertPost {
  final String id, title, severity, zone, advisory;
  final double latitude, longitude;
  final DateTime publishedAt;
  final bool rangerEnRoute, resolved;
  const CommunityAlertPost({
    required this.id,
    required this.title,
    required this.severity,
    required this.zone,
    required this.advisory,
    required this.latitude,
    required this.longitude,
    required this.publishedAt,
    this.rangerEnRoute = false,
    this.resolved = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'severity': severity,
    'zone': zone,
    'advisory': advisory,
    'latitude': latitude,
    'longitude': longitude,
    'publishedAt': publishedAt.toIso8601String(),
    'rangerEnRoute': rangerEnRoute,
    'resolved': resolved,
  };
  factory CommunityAlertPost.fromJson(Map<String, dynamic> j) =>
      CommunityAlertPost(
        id: j['id'],
        title: j['title'],
        severity: j['severity'] ?? 'MEDIUM',
        zone: j['zone'] ?? 'Unspecified zone',
        advisory: j['advisory'] ?? '',
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        publishedAt:
            DateTime.tryParse(j['publishedAt'] ?? '') ?? DateTime.now(),
        rangerEnRoute: j['rangerEnRoute'] ?? false,
        resolved: j['resolved'] ?? false,
      );
}
