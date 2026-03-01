class NewsItem {
  final String id;
  final String title;
  final String source;
  final String summary;
  final int riskScore;

  final String clientId;
  final String regionId;
  final String siteId;

  const NewsItem({
    required this.id,
    required this.title,
    required this.source,
    required this.summary,
    required this.riskScore,
    required this.clientId,
    required this.regionId,
    required this.siteId,
  });
}
