class Site {
  static const double defaultLatitude = -26.2041;
  static const double defaultLongitude = 28.0473;

  final String siteId;
  final String clientId;
  final String name;
  final String geoReference;
  final double latitude;
  final double longitude;
  final String createdAt;

  const Site({
    required this.siteId,
    required this.clientId,
    required this.name,
    required this.geoReference,
    this.latitude = defaultLatitude,
    this.longitude = defaultLongitude,
    required this.createdAt,
  });
}
