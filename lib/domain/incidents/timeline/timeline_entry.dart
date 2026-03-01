class TimelineEntry {
  final String label;
  final String timestamp;
  final Map<String, dynamic> metadata;

  const TimelineEntry({
    required this.label,
    required this.timestamp,
    required this.metadata,
  });
}
