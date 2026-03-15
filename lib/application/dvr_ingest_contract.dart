import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'video_edge_ingest_contract.dart';

class DvrProviderProfile {
  final String provider;
  final String schemaId;
  final String eventTransport;
  final String snapshotPathTemplate;
  final String clipPathTemplate;
  final VideoAnalyticsCapabilities capabilities;
  final bool privateEvidenceFetch;

  const DvrProviderProfile({
    required this.provider,
    required this.schemaId,
    required this.eventTransport,
    required this.snapshotPathTemplate,
    required this.clipPathTemplate,
    required this.capabilities,
    this.privateEvidenceFetch = true,
  });

  static DvrProviderProfile? fromProvider(String provider) {
    final key = provider.trim().toLowerCase().replaceAll('-', '_');
    if (key.isEmpty) {
      return null;
    }
    if (key.contains('hikvision') && key.contains('monitor_only')) {
      return hikvisionMonitorOnly;
    }
    if (key.contains('hikvision')) {
      return hikvisionIsapi;
    }
    if (key.contains('generic')) {
      return genericEventList;
    }
    return null;
  }

  static const hikvisionIsapi = DvrProviderProfile(
    provider: 'hikvision_dvr',
    schemaId: 'hikvision_isapi_event_notification_alert',
    eventTransport: 'isapi_alert_stream',
    snapshotPathTemplate: '/ISAPI/Streaming/channels/{streamId}/picture',
    clipPathTemplate: '',
    capabilities: VideoAnalyticsCapabilities(
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: false,
    ),
  );

  static const hikvisionMonitorOnly = DvrProviderProfile(
    provider: 'hikvision_dvr_monitor_only',
    schemaId: 'hikvision_isapi_event_notification_alert',
    eventTransport: 'isapi_alert_stream',
    snapshotPathTemplate: '/ISAPI/Streaming/channels/{streamId}/picture',
    clipPathTemplate: '',
    capabilities: VideoAnalyticsCapabilities(
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: false,
    ),
  );

  static const genericEventList = DvrProviderProfile(
    provider: 'generic_dvr',
    schemaId: 'generic_dvr_event_list',
    eventTransport: 'http_pull',
    snapshotPathTemplate: '/api/dvr/events/{eventId}/snapshot.jpg',
    clipPathTemplate: '/api/dvr/events/{eventId}/clip.mp4',
    capabilities: VideoAnalyticsCapabilities(
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: false,
    ),
  );

  String? buildSnapshotUrl(Uri baseUri, String eventId, {String? channelId}) {
    if (snapshotPathTemplate.trim().isEmpty) {
      return null;
    }
    final streamId = _streamId(channelId);
    return baseUri
        .resolve(
          snapshotPathTemplate
              .replaceAll('{eventId}', Uri.encodeComponent(eventId))
              .replaceAll('{channelId}', Uri.encodeComponent(channelId ?? ''))
              .replaceAll('{streamId}', Uri.encodeComponent(streamId)),
        )
        .toString();
  }

  String? buildClipUrl(Uri baseUri, String eventId, {String? channelId}) {
    if (clipPathTemplate.trim().isEmpty) {
      return null;
    }
    final streamId = _streamId(channelId);
    return baseUri
        .resolve(
          clipPathTemplate
              .replaceAll('{eventId}', Uri.encodeComponent(eventId))
              .replaceAll('{channelId}', Uri.encodeComponent(channelId ?? ''))
              .replaceAll('{streamId}', Uri.encodeComponent(streamId)),
        )
        .toString();
  }

  String _streamId(String? channelId) {
    final digits = channelId?.trim() ?? '';
    return RegExp(r'^\d+$').hasMatch(digits) ? '${digits}01' : '';
  }
}

class DvrFixtureContractNormalizer {
  final DvrProviderProfile profile;
  final Uri baseUri;

  const DvrFixtureContractNormalizer({
    required this.profile,
    required this.baseUri,
  });

  VideoEdgeEventContract? normalize({
    required Object? payload,
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final normalized = switch (profile.schemaId) {
      'hikvision_isapi_event_notification_alert' => _normalizeHikvisionIsapi(
        payload,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      'generic_dvr_event_list' => _normalizeGenericDvrEvent(
        payload,
        clientId: clientId,
        regionId: regionId,
        siteId: siteId,
      ),
      _ => null,
    };
    return normalized;
  }

  VideoEdgeEventContract? _normalizeHikvisionIsapi(
    Object? payload, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final root = _toObjectMap(payload);
    final alert = _toObjectMap(root['EventNotificationAlert']);
    if (alert.isEmpty) {
      return null;
    }
    final eventState = _stringValue(alert, const ['eventState']).toLowerCase();
    if (eventState.isNotEmpty && eventState != 'active') {
      return null;
    }
    final channelId = _stringValue(alert, const ['channelID', 'dynChannelID']);
    final eventId = _stringValue(alert, const [
      'UUID',
      'eventId',
      'eventID',
      'id',
    ]);
    final occurredAtUtc = _parseDateTime(
      _stringValue(alert, const ['dateTime', 'timestamp', 'UTC']),
    );
    if (occurredAtUtc == null) {
      return null;
    }
    final externalId = eventId.isNotEmpty
        ? eventId
        : _syntheticHikvisionEventId(alert, occurredAtUtc, channelId);
    final zone = _extractHikvisionZone(alert);
    final faceData = _toObjectMap(alert['Faces']);
    final anprData = _toObjectMap(alert['ANPR']);
    final targetType = _stringValue(alert, const ['targetType']).trim();
    final eventType = _eventHeadline(
      provider: profile.provider,
      eventType: _stringValue(alert, const [
        'eventType',
        'eventDescription',
        'eventTypeEx',
      ]),
    );
    return VideoEdgeEventContract(
      provider: profile.provider,
      sourceType: 'dvr',
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: _hikvisionCameraId(channelId),
      channelId: channelId,
      zone: zone,
      objectLabel: targetType.isNotEmpty
          ? targetType.toLowerCase()
          : _objectLabelFromEventType(
              _stringValue(alert, const ['eventType', 'eventTypeEx']),
            ),
      objectConfidence: _doubleValue(alert, const [
        'confidence',
        'Confidence',
        'probability',
      ]),
      faceMatchId: _stringValue(faceData, const [
        'matchId',
        'faceMatchId',
        'id',
      ]),
      faceConfidence: _doubleValue(faceData, const [
        'confidence',
        'score',
        'Similarity',
      ]),
      plateNumber: _stringValue(anprData, const [
        'licensePlate',
        'plateNumber',
        'PlateNumber',
      ]),
      plateConfidence: _doubleValue(anprData, const [
        'confidence',
        'score',
        'Similarity',
      ]),
      headline: eventType,
      riskScore: _riskScore(
        liveMonitoring: profile.capabilities.liveMonitoringEnabled,
        hasFace: _stringValue(faceData, const [
          'matchId',
          'faceMatchId',
        ]).isNotEmpty,
        hasPlate: _stringValue(anprData, const [
          'licensePlate',
          'plateNumber',
        ]).isNotEmpty,
      ),
      occurredAtUtc: occurredAtUtc,
      capabilities: profile.capabilities,
      evidence: VideoEvidenceReference(
        snapshotUrl: profile.buildSnapshotUrl(
          baseUri,
          externalId,
          channelId: channelId,
        ),
        clipUrl: profile.buildClipUrl(
          baseUri,
          externalId,
          channelId: channelId,
        ),
        snapshotExpected: true,
        clipExpected:
            profile.buildClipUrl(baseUri, externalId, channelId: channelId) !=
            null,
        accessMode: profile.privateEvidenceFetch
            ? VideoEvidenceAccessMode.privateFetch
            : VideoEvidenceAccessMode.directUrl,
      ),
      attributes: <String, Object?>{
        'schema_id': profile.schemaId,
        'event_state': _stringValue(alert, const ['eventState']),
        'event_description': _stringValue(alert, const ['eventDescription']),
      },
    );
  }

  VideoEdgeEventContract? _normalizeGenericDvrEvent(
    Object? payload, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final map = _toObjectMap(payload);
    final eventId = _stringValue(map, const ['id', 'event_id', 'uuid']);
    final occurredAtUtc = _parseDateTime(
      _stringValue(map, const ['timestamp', 'occurred_at_utc']),
    );
    if (eventId.isEmpty || occurredAtUtc == null) {
      return null;
    }
    return VideoEdgeEventContract(
      provider: profile.provider,
      sourceType: 'dvr',
      externalId: eventId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: _stringValue(map, const ['camera_id', 'camera', 'device_id']),
      channelId: _stringValue(map, const ['channel', 'channel_id']),
      zone: _stringValue(map, const ['zone', 'area']),
      objectLabel: _stringValue(map, const ['label', 'object']),
      objectConfidence: _doubleValue(map, const ['confidence', 'score']),
      headline: _eventHeadline(
        provider: profile.provider,
        eventType: _stringValue(map, const ['event_type', 'type', 'topic']),
      ),
      riskScore: 72,
      occurredAtUtc: occurredAtUtc,
      capabilities: profile.capabilities,
      evidence: VideoEvidenceReference(
        snapshotUrl: profile.buildSnapshotUrl(baseUri, eventId),
        clipUrl: profile.buildClipUrl(baseUri, eventId),
        snapshotExpected: profile.buildSnapshotUrl(baseUri, eventId) != null,
        clipExpected: profile.buildClipUrl(baseUri, eventId) != null,
        accessMode: profile.privateEvidenceFetch
            ? VideoEvidenceAccessMode.privateFetch
            : VideoEvidenceAccessMode.directUrl,
      ),
      attributes: const <String, Object?>{
        'schema_id': 'generic_dvr_event_list',
      },
    );
  }

  Map<String, Object?> _toObjectMap(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
      );
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      return _toObjectMap(decoded);
    }
    return const <String, Object?>{};
  }

  String _stringValue(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  double? _doubleValue(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      if (value is num) {
        return value.toDouble();
      }
      final parsed = double.tryParse(value.toString().trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  DateTime? _parseDateTime(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  String _extractHikvisionZone(Map<String, Object?> alert) {
    final regionList = _toObjectMap(alert['detectionRegionList']);
    final entries = regionList['detectionRegionEntry'];
    if (entries is List && entries.isNotEmpty) {
      final entry = _toObjectMap(entries.first);
      return _stringValue(entry, const ['regionID', 'regionType']);
    }
    return _stringValue(alert, const ['zone', 'regionID']);
  }

  String _eventHeadline({required String provider, required String eventType}) {
    final normalized = eventType.trim().toUpperCase().replaceAll('-', '_');
    if (normalized == 'VMD' || normalized.contains('MOTION')) {
      return '${provider.toUpperCase()} MOTION';
    }
    if (normalized.contains('LINE') || normalized.contains('CROSS')) {
      return '${provider.toUpperCase()} LINE_CROSSING';
    }
    if (normalized.contains('INTRUSION')) {
      return '${provider.toUpperCase()} INTRUSION';
    }
    return '${provider.toUpperCase()} VIDEO_EVENT';
  }

  String? _objectLabelFromEventType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'vmd') {
      return 'motion';
    }
    if (value.contains('line')) {
      return 'line_crossing';
    }
    if (value.contains('intrusion')) {
      return 'intrusion';
    }
    if (value.contains('motion')) {
      return 'motion';
    }
    return null;
  }

  int _riskScore({
    required bool liveMonitoring,
    required bool hasFace,
    required bool hasPlate,
  }) {
    var score = liveMonitoring ? 78 : 62;
    if (hasFace) {
      score += 8;
    }
    if (hasPlate) {
      score += 6;
    }
    return score.clamp(1, 99);
  }

  String _syntheticHikvisionEventId(
    Map<String, Object?> alert,
    DateTime occurredAtUtc,
    String channelId,
  ) {
    final seed = [
      _stringValue(alert, const ['ipAddress', 'macAddress', 'deviceID']),
      channelId,
      _stringValue(alert, const [
        'eventType',
        'eventDescription',
        'targetType',
      ]),
      occurredAtUtc.toIso8601String(),
    ].join('|');
    return md5.convert(utf8.encode(seed)).toString();
  }

  String _hikvisionCameraId(String channelId) {
    final digits = channelId.trim();
    return digits.isEmpty ? 'channel-unknown' : 'channel-$digits';
  }
}
