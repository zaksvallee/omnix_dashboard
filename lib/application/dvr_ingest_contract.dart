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
    if (key.contains('hik_connect') || key.contains('hikcentral_connect')) {
      return hikConnectOpenApi;
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

  static const hikConnectOpenApi = DvrProviderProfile(
    provider: 'hik_connect_openapi',
    schemaId: 'hik_connect_alarm_msg',
    eventTransport: 'hik_connect_alarm_mq_pull',
    snapshotPathTemplate: '',
    clipPathTemplate: '',
    capabilities: VideoAnalyticsCapabilities(
      liveMonitoringEnabled: true,
      facialRecognitionEnabled: false,
      licensePlateRecognitionEnabled: true,
    ),
    privateEvidenceFetch: false,
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
      'hik_connect_alarm_msg' => _normalizeHikConnectAlarmMsg(
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
    final rawEventType = _stringValue(alert, const [
      'eventType',
      'eventDescription',
      'eventTypeEx',
    ]);
    final canonicalEventType = _canonicalEventType(rawEventType);
    if (eventState.isNotEmpty &&
        eventState != 'active' &&
        !_shouldRetainInactiveHikvisionEvent(
          canonicalEventType: canonicalEventType,
          eventState: eventState,
        )) {
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
    final eventType = _hikvisionEventHeadline(
      provider: profile.provider,
      canonicalEventType: canonicalEventType,
      eventState: eventState,
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
      riskScore: eventState == 'active'
          ? _riskScore(
              liveMonitoring: profile.capabilities.liveMonitoringEnabled,
              hasFace: _stringValue(faceData, const [
                'matchId',
                'faceMatchId',
              ]).isNotEmpty,
              hasPlate: _stringValue(anprData, const [
                'licensePlate',
                'plateNumber',
              ]).isNotEmpty,
            )
          : 8,
      occurredAtUtc: occurredAtUtc,
      summaryOverride: _hikvisionEventSummaryOverride(
        canonicalEventType: canonicalEventType,
        eventState: eventState,
        eventDescription: _stringValue(alert, const ['eventDescription']),
        cameraId: _hikvisionCameraId(channelId),
      ),
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

  bool _shouldRetainInactiveHikvisionEvent({
    required String canonicalEventType,
    required String eventState,
  }) {
    if (eventState == 'active' || eventState.isEmpty) {
      return true;
    }
    return canonicalEventType == 'video_loss' &&
        (eventState == 'inactive' ||
            eventState == 'inactivepost' ||
            eventState == 'stop');
  }

  String _hikvisionEventHeadline({
    required String provider,
    required String canonicalEventType,
    required String eventState,
  }) {
    final base = _eventHeadline(
      provider: provider,
      eventType: canonicalEventType,
    );
    if (eventState == 'active' || eventState.isEmpty) {
      return base;
    }
    if (canonicalEventType == 'video_loss' &&
        (eventState == 'inactive' ||
            eventState == 'inactivepost' ||
            eventState == 'stop')) {
      return '${base}_CLEARED';
    }
    return base;
  }

  String? _hikvisionEventSummaryOverride({
    required String canonicalEventType,
    required String eventState,
    required String eventDescription,
    required String cameraId,
  }) {
    if (eventState == 'active' || eventState.isEmpty) {
      return null;
    }
    final description = eventDescription.trim().isEmpty
        ? canonicalEventType.replaceAll('_', ' ')
        : eventDescription.trim();
    final normalizedDescription = description.toLowerCase();
    final cameraDetail = cameraId.trim().isEmpty ? '' : 'camera:$cameraId | ';
    final suffix = normalizedDescription.contains('alarm')
        ? eventState
        : 'alarm $eventState';
    return '$cameraDetail$normalizedDescription $suffix';
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

  VideoEdgeEventContract? _normalizeHikConnectAlarmMsg(
    Object? payload, {
    required String clientId,
    required String regionId,
    required String siteId,
  }) {
    final map = _toObjectMap(payload);
    if (map.isEmpty) {
      return null;
    }
    final msgType = _stringValue(map, const ['msgType']);
    final alarmState = _stringValue(map, const ['alarmState']);
    if (msgType.isNotEmpty && msgType != '1' && alarmState != '1') {
      return null;
    }
    final eventSource = _toObjectMap(map['eventSource']);
    final timeInfo = _toObjectMap(map['timeInfo']);
    final fileInfo = _toObjectMap(map['fileInfo']);
    final alarmRule = _toObjectMap(map['alarmRule']);
    final anprInfo = _toObjectMap(map['anprInfo']);
    final faceInfo = _extractHikConnectFaceInfo(map);
    final deviceInfo = _toObjectMap(eventSource['deviceInfo']);
    final occurredAtUtc = _parseDateTime(
      _stringValue(timeInfo, const [
        'startTime',
        'startTimeLocal',
        'endTime',
        'endTimeLocal',
      ]),
    );
    if (occurredAtUtc == null) {
      return null;
    }
    final externalId = _stringValue(map, const ['guid', 'systemId']);
    if (externalId.isEmpty) {
      return null;
    }
    final eventType = _stringValue(eventSource, const ['eventType']);
    final sourceName = _stringValue(eventSource, const ['sourceName']);
    final sourceId = _stringValue(eventSource, const ['sourceID']);
    final areaName = _stringValue(eventSource, const ['areaName']);
    final ruleName = _stringValue(alarmRule, const ['name']);
    final plateNumber = _stringValue(anprInfo, const ['licensePlate']);
    final faceMatchId =
        _stringValue(faceInfo, const [
          'faceMatchId',
          'face_id',
          'matchId',
          'personId',
          'personID',
          'humanName',
          'name',
        ]).isNotEmpty
        ? _stringValue(faceInfo, const [
            'faceMatchId',
            'face_id',
            'matchId',
            'personId',
            'personID',
            'humanName',
            'name',
          ])
        : _stringValue(map, const [
            'faceMatchId',
            'face_id',
            'matchId',
            'personId',
            'personID',
            'humanName',
            'name',
          ]);
    final faceConfidence =
        _doubleValue(faceInfo, const [
          'faceConfidence',
          'face_confidence',
          'similarity',
          'Similarity',
          'confidence',
          'score',
        ]) ??
        _doubleValue(map, const [
          'faceConfidence',
          'face_confidence',
          'similarity',
          'Similarity',
          'confidence',
          'score',
        ]);
    final alarmSubCategory = _stringValue(map, const ['alarmSubCategory']);
    final canonicalEventType = _hikConnectCanonicalEventType(
      eventType: eventType,
      alarmSubCategory: alarmSubCategory,
      ruleName: ruleName,
      plateNumber: plateNumber,
    );
    final evidence = _extractHikConnectEvidence(fileInfo);
    final objectLabel = plateNumber.isNotEmpty
        ? 'vehicle'
        : faceMatchId.isNotEmpty
        ? 'person'
        : _objectLabelFromEventType(canonicalEventType);
    final summaryParts = <String>[
      'provider:${profile.provider}',
      if (sourceName.isNotEmpty) 'camera:$sourceName',
      if (sourceId.isNotEmpty) 'resource:$sourceId',
      if (areaName.isNotEmpty) 'area:$areaName',
      if (ruleName.isNotEmpty) 'rule:$ruleName',
      if (faceMatchId.isNotEmpty) 'FR:$faceMatchId',
      if (plateNumber.isNotEmpty) 'LPR:$plateNumber',
      'snapshot:${evidence.snapshotStatus()}',
      'clip:${evidence.clipStatus()}',
    ];
    return VideoEdgeEventContract(
      provider: profile.provider,
      sourceType: 'dvr',
      externalId: externalId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      cameraId: sourceId.isNotEmpty ? sourceId : sourceName,
      channelId: '',
      zone: areaName,
      objectLabel: objectLabel,
      objectConfidence: null,
      faceMatchId: faceMatchId,
      faceConfidence: faceConfidence,
      plateNumber: plateNumber,
      plateConfidence: null,
      headline: _eventHeadline(
        provider: profile.provider,
        eventType: canonicalEventType,
      ),
      riskScore: _riskScore(
        liveMonitoring: profile.capabilities.liveMonitoringEnabled,
        hasFace: faceMatchId.isNotEmpty,
        hasPlate: plateNumber.isNotEmpty,
      ),
      occurredAtUtc: occurredAtUtc,
      summaryOverride: summaryParts.join(' | '),
      capabilities: profile.capabilities,
      evidence: evidence,
      attributes: <String, Object?>{
        'schema_id': profile.schemaId,
        'msg_type': msgType,
        'alarm_state': alarmState,
        'alarm_sub_category': alarmSubCategory,
        'device_name': _stringValue(deviceInfo, const ['devName']),
      },
    );
  }

  Map<String, Object?> _extractHikConnectFaceInfo(Map<String, Object?> map) {
    for (final key in const [
      'faceInfo',
      'faceMatchInfo',
      'personInfo',
      'targetInfo',
      'faceData',
    ]) {
      final nested = _toObjectMap(map[key]);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return const <String, Object?>{};
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
    final canonical = _canonicalEventType(eventType);
    final suffix = switch (canonical) {
      'motion' => 'MOTION',
      'line_crossing' => 'LINE_CROSSING',
      'intrusion' => 'INTRUSION',
      'video_loss' => 'VIDEO_LOSS',
      'fr_match' => 'FR_MATCH',
      'lpr_alert' => 'LPR_ALERT',
      _ => 'VIDEO_EVENT',
    };
    return '${provider.toUpperCase()} $suffix';
  }

  String? _objectLabelFromEventType(String raw) {
    return switch (_canonicalEventType(raw)) {
      'motion' => 'motion',
      'line_crossing' => 'line_crossing',
      'intrusion' => 'intrusion',
      'fr_match' => 'person',
      'lpr_alert' => 'vehicle',
      _ => null,
    };
  }

  String _canonicalEventType(String raw) {
    final value = _normalizeEventToken(raw);
    if (value.isEmpty) {
      return 'video_event';
    }
    if (value == 'vmd' || value.contains('motion')) {
      return 'motion';
    }
    if (value.contains('videoloss') || value.contains('signalloss')) {
      return 'video_loss';
    }
    if (value.contains('line') ||
        value.contains('cross') ||
        value.contains('tripwire')) {
      return 'line_crossing';
    }
    if (value.contains('intrusion') ||
        value.contains('fielddetection') ||
        value.contains('regionentrance') ||
        value.contains('regionexit')) {
      return 'intrusion';
    }
    if (value.contains('face') || value.contains('frmatch')) {
      return 'fr_match';
    }
    if (value.contains('plate') ||
        value.contains('license') ||
        value.contains('anpr') ||
        value.contains('lpr')) {
      return 'lpr_alert';
    }
    return 'video_event';
  }

  String _normalizeEventToken(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _hikConnectCanonicalEventType({
    required String eventType,
    required String alarmSubCategory,
    required String ruleName,
    required String plateNumber,
  }) {
    if (plateNumber.trim().isNotEmpty) {
      return 'lpr_alert';
    }
    return _canonicalEventType('$eventType $alarmSubCategory $ruleName');
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

  VideoEvidenceReference _extractHikConnectEvidence(
    Map<String, Object?> fileInfo,
  ) {
    final rawFiles = fileInfo['file'];
    final files = rawFiles is List
        ? rawFiles.map(_toObjectMap).where((entry) => entry.isNotEmpty).toList()
        : const <Map<String, Object?>>[];
    String? snapshotUrl;
    String? clipUrl;
    for (final file in files) {
      final type = _stringValue(file, const ['type']);
      final url = _stringValue(file, const ['URL', 'url']);
      if (url.isEmpty) {
        continue;
      }
      if (type == '1' && snapshotUrl == null) {
        snapshotUrl = url;
      } else if (type == '2' && clipUrl == null) {
        clipUrl = url;
      }
    }
    return VideoEvidenceReference(
      snapshotUrl: snapshotUrl,
      clipUrl: clipUrl,
      snapshotExpected: snapshotUrl != null,
      clipExpected: clipUrl != null,
      accessMode: VideoEvidenceAccessMode.directUrl,
    );
  }
}
