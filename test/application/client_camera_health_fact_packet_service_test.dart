import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:omnix_dashboard/application/dvr_bridge_service.dart';
import 'package:omnix_dashboard/application/dvr_scope_config.dart';
import 'package:omnix_dashboard/application/monitoring_watch_continuous_visual_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/application/video_bridge_runtime.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  const service = ClientCameraHealthFactPacketService();

  test(
    'build marks Vallee legacy localhost proxy path as live when probes are fresh',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 14, 30);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final evidenceSnapshot = VideoEvidenceProbeSnapshot(
        verifiedCount: 2,
        lastRunAtUtc: nowUtc.subtract(const Duration(minutes: 4)),
        cameras: [
          VideoCameraHealth(
            cameraId: 'cam-1',
            snapshotVerified: 1,
            lastSeenAtUtc: nowUtc.subtract(const Duration(minutes: 6)),
            status: 'healthy',
          ),
        ],
      );
      final watchRuntime = MonitoringWatchRuntimeState(
        startedAtUtc: nowUtc.subtract(const Duration(hours: 1)),
        monitoringAvailable: true,
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: true,
        running: true,
        lastSuccessAtUtc: nowUtc.subtract(const Duration(minutes: 2)),
      );
      final recentIntelligence = [
        IntelligenceReceived(
          eventId: 'event-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 3)),
          intelligenceId: 'intel-1',
          provider: 'hikvision',
          sourceType: 'dvr',
          externalId: 'ext-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'cam-1',
          headline: 'Camera visual confirmed',
          summary: 'Latest verified camera activity for the site.',
          riskScore: 10,
          snapshotUrl:
              'http://127.0.0.1:11635/ISAPI/Streaming/channels/1/picture',
          canonicalHash: 'hash-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        evidenceSnapshot: evidenceSnapshot,
        watchRuntime: watchRuntime,
        recentIntelligence: recentIntelligence,
        localProxyHealth: localProxyHealth,
        nowUtc: nowUtc,
      );

      expect(packet.status, ClientCameraHealthStatus.live);
      expect(packet.reason, ClientCameraHealthReason.legacyProxyActive);
      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(
        packet.lastSuccessfulVisualAtUtc,
        nowUtc.subtract(const Duration(minutes: 3)),
      );
      expect(packet.currentVisualSnapshotUri, isNull);
      expect(packet.currentVisualRelayStreamUri, isNull);
      expect(packet.currentVisualRelayPlayerUri, isNull);
      expect(packet.currentVisualCameraId, isNull);
      expect(packet.currentVisualVerifiedAtUtc, isNull);
      expect(
        packet.lastSuccessfulUpstreamProbeAtUtc,
        nowUtc.subtract(const Duration(minutes: 2)),
      );
      expect(packet.nextAction, contains('127.0.0.1:11635'));
      expect(
        packet.safeClientExplanation,
        equals('We currently have visual confirmation at MS Vallee Residence.'),
      );
    },
  );

  test('build marks Hik-Connect scopes without credentials as offline', () {
    final nowUtc = DateTime.utc(2026, 4, 3, 14, 30);
    final scope = DvrScopeConfig(
      clientId: 'CLIENT-MS-VALLEE',
      regionId: 'REGION-JHB',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      provider: 'hik_connect_openapi',
      eventsUri: null,
      apiBaseUri: Uri.parse('https://api.hik-connect.example'),
      authMode: 'none',
      username: '',
      password: '',
      bearerToken: '',
      appKey: '',
      appSecret: '',
    );

    final packet = service.build(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteReference: 'MS Vallee Residence',
      scope: scope,
      nowUtc: nowUtc,
    );

    expect(packet.path, ClientCameraHealthPath.hikConnectApi);
    expect(packet.reason, ClientCameraHealthReason.credentialsMissing);
    expect(packet.status, ClientCameraHealthStatus.offline);
    expect(packet.nextAction, contains('Hik-Connect credentials'));
    expect(
      packet.safeClientExplanation,
      equals(
        'Live camera visibility at MS Vallee Residence is unavailable right now.',
      ),
    );
  });

  test(
    'build marks the legacy localhost path as offline when the proxy is down',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 14, 30);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final watchRuntime = MonitoringWatchRuntimeState(
        startedAtUtc: nowUtc.subtract(const Duration(hours: 1)),
        monitoringAvailable: false,
        monitoringAvailabilityDetail: 'Local bridge offline.',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: false,
        running: false,
        lastError: 'Connection refused',
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        watchRuntime: watchRuntime,
        localProxyHealth: localProxyHealth,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(packet.reason, ClientCameraHealthReason.bridgeOffline);
      expect(packet.status, ClientCameraHealthStatus.offline);
      expect(packet.nextAction, contains('Restore the local camera bridge'));
      expect(
        packet.safeClientExplanation,
        equals(
          'Live camera visibility at MS Vallee Residence is unavailable right now.',
        ),
      );
    },
  );

  test(
    'fresh site awareness upgrades an offline packet to limited monitoring',
    () {
      final nowUtc = DateTime.utc(2026, 4, 9, 8, 0);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        localProxyHealth: LocalHikvisionDvrProxyHealthSnapshot(
          healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
          reachable: false,
          running: false,
          lastError: 'Connection refused',
        ),
        nowUtc: nowUtc,
      );

      final reconciled = reconcileClientCameraHealthWithSiteAwareness(
        packet: packet,
        observedAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
        perimeterClear: true,
        humanCount: 2,
      );

      expect(reconciled.status, ClientCameraHealthStatus.limited);
      expect(reconciled.reason, ClientCameraHealthReason.legacyProxyActive);
      expect(
        reconciled.lastSuccessfulUpstreamProbeAtUtc,
        nowUtc.subtract(const Duration(minutes: 1)),
      );
      expect(
        reconciled.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.active,
      );
      expect(
        reconciled.liveSiteIssueStatus,
        ClientLiveSiteIssueStatus.noConfirmedIssue,
      );
      expect(reconciled.recentMovementSignalCount, 2);
      expect(reconciled.recentMovementObjectLabel, 'humans');
      expect(
        reconciled.safeClientExplanation,
        contains('people on site with no perimeter breach'),
      );
    },
  );

  test('fresh site awareness preserves active perimeter alerts', () {
    final nowUtc = DateTime.utc(2026, 4, 9, 8, 15);
    final packet = service.build(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteReference: 'MS Vallee Residence',
      nowUtc: nowUtc,
    );

    final reconciled = reconcileClientCameraHealthWithSiteAwareness(
      packet: packet,
      observedAtUtc: nowUtc,
      perimeterClear: false,
    );

    expect(
      reconciled.liveSiteIssueStatus,
      ClientLiveSiteIssueStatus.activeSignals,
    );
    expect(reconciled.recentIssueSignalLabel, 'active perimeter alert');
    expect(reconciled.nextAction, contains('perimeter alert'));
  });

  test(
    'build does not mark the legacy localhost path offline when the relay is still live',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 15, 42);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: false,
        running: false,
        lastError: 'Proxy health HTTP 503',
      );
      final localVisualProbe = LocalHikvisionDvrVisualProbeSnapshot(
        snapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        cameraId: 'channel-11',
        reachable: true,
        verifiedAtUtc: nowUtc.subtract(const Duration(minutes: 3)),
      );
      final localRelayProbe = LocalHikvisionDvrRelayProbeSnapshot(
        streamUri: Uri.parse('http://127.0.0.1:11635/stream/channel-11'),
        playerUri: Uri.parse('http://127.0.0.1:11635/player/channel-11'),
        checkedAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
        verifiedAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
        relayStatus: ClientCameraRelayStatus.active,
        streamReachable: true,
        playerReachable: true,
        lastFrameAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
        activeClientCount: 1,
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        localProxyHealth: localProxyHealth,
        localVisualProbe: localVisualProbe,
        localRelayProbe: localRelayProbe,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(packet.reason, ClientCameraHealthReason.legacyProxyActive);
      expect(packet.status, ClientCameraHealthStatus.live);
      expect(packet.currentVisualRelayStreamUri, isNotNull);
      expect(packet.currentVisualRelayPlayerUri, isNotNull);
      expect(
        packet.safeClientExplanation,
        equals('We currently have visual confirmation at MS Vallee Residence.'),
      );
      expect(
        packet.safeClientExplanation,
        isNot(contains('currently unavailable')),
      );
    },
  );

  test(
    'build promotes recent motion intelligence into live-site movement state',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 18, 5);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = [
        IntelligenceReceived(
          eventId: 'event-motion-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 4)),
          intelligenceId: 'intel-motion-1',
          provider: 'hikvision',
          sourceType: 'dvr',
          externalId: 'ext-motion-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: '11',
          zone: 'Front Gate',
          objectLabel: 'person',
          headline: 'Front gate motion alert',
          summary: 'Motion detection alarm triggered near the front gate.',
          riskScore: 38,
          canonicalHash: 'hash-motion-1',
        ),
        IntelligenceReceived(
          eventId: 'event-motion-2',
          sequence: 2,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 2)),
          intelligenceId: 'intel-motion-2',
          provider: 'hikvision',
          sourceType: 'dvr',
          externalId: 'ext-motion-2',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: '11',
          zone: 'Front Gate',
          objectLabel: 'person',
          headline: 'Repeat person movement',
          summary: 'Identified repeat movement activity on Camera 11.',
          riskScore: 42,
          canonicalHash: 'hash-motion-2',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(
        packet.liveSiteIssueStatus,
        ClientLiveSiteIssueStatus.recentSignals,
      );
      expect(packet.hasRecentMovementSignals, isTrue);
      expect(packet.recentMovementSignalCount, 2);
      expect(
        packet.recentMovementSignalLabel,
        contains('person movement signals'),
      );
      expect(packet.recentMovementSignalLabel, contains('Front Gate'));
      expect(
        packet.lastMovementSignalAtUtc,
        nowUtc.subtract(const Duration(minutes: 2)),
      );
    },
  );

  test(
    'build surfaces recent YOLO semantic detections through movement labels',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 18, 40);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = <IntelligenceReceived>[
        IntelligenceReceived(
          eventId: 'event-yolo-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-yolo-1',
          provider: 'hikvision_local_yolo',
          sourceType: 'dvr',
          externalId: 'ext-yolo-1#yolo:vehicle',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: '11',
          zone: 'Driveway',
          objectLabel: 'vehicle',
          objectConfidence: 0.89,
          headline: 'YOLO detected vehicle activity near Driveway',
          summary:
              'YOLO classified the recent camera activity near Driveway as vehicle.',
          riskScore: 62,
          canonicalHash: 'hash-yolo-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(packet.recentMovementObjectLabel, 'vehicle');
      expect(
        packet.recentMovementSignalLabel,
        'recent vehicle movement signals around Driveway',
      );
    },
  );

  test(
    'build preserves higher-risk semantic detections like knives in live movement labels',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 18, 44);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'basic',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = <IntelligenceReceived>[
        IntelligenceReceived(
          eventId: 'event-yolo-knife-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-yolo-knife-1',
          provider: 'hikvision_local_yolo',
          sourceType: 'dvr',
          externalId: 'ext-yolo-knife-1#yolo:knife',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: '11',
          zone: 'Front Gate',
          objectLabel: 'knife',
          objectConfidence: 0.88,
          headline: 'YOLO detected a knife near Front Gate',
          summary: 'YOLO detected a knife near Front Gate.',
          riskScore: 86,
          canonicalHash: 'hash-yolo-knife-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(packet.recentMovementObjectLabel, 'knife');
      expect(
        packet.recentMovementSignalLabel,
        'recent knife detections around Front Gate',
      );
    },
  );

  test(
    'build infers vehicle semantics from plate-bearing alerts without an explicit object label',
    () {
      final nowUtc = DateTime.utc(2026, 4, 5, 9, 5);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hik_connect_openapi',
        eventsUri: Uri.parse('https://api.hik-connect.example.com'),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = <IntelligenceReceived>[
        IntelligenceReceived(
          eventId: 'event-lpr-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-lpr-1',
          provider: 'hik_connect_openapi',
          sourceType: 'dvr',
          externalId: 'ext-lpr-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'camera-front',
          zone: 'Front Driveway',
          plateNumber: 'CA123456',
          headline: 'HIK_CONNECT_OPENAPI LPR_ALERT',
          summary:
              'provider:hik_connect_openapi | camera:Front Yard | area:Front Driveway | LPR:CA123456',
          riskScore: 76,
          canonicalHash: 'hash-lpr-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(packet.recentMovementObjectLabel, 'vehicle');
      expect(
        packet.recentMovementSignalLabel,
        'recent vehicle movement signals around Front Driveway',
      );
      expect(
        packet.recentIssueSignalLabel,
        'recent vehicle activity around Front Driveway',
      );
    },
  );

  test(
    'build infers person semantics from hik-connect face-match alerts without an explicit object label',
    () {
      final nowUtc = DateTime.utc(2026, 4, 5, 9, 7);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hik_connect_openapi',
        eventsUri: Uri.parse('https://api.hik-connect.example.com'),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = <IntelligenceReceived>[
        IntelligenceReceived(
          eventId: 'event-fr-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-fr-1',
          provider: 'hik_connect_openapi',
          sourceType: 'dvr',
          externalId: 'ext-fr-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'camera-lobby',
          zone: 'Reception',
          faceMatchId: 'RESIDENT-44',
          faceConfidence: 91.2,
          headline: 'HIK_CONNECT_OPENAPI FR_MATCH',
          summary:
              'provider:hik_connect_openapi | camera:Lobby Camera | area:Reception | FR:RESIDENT-44',
          riskScore: 81,
          canonicalHash: 'hash-fr-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(packet.recentMovementObjectLabel, 'person');
      expect(
        packet.recentMovementSignalLabel,
        'recent person movement signals around Reception',
      );
      expect(
        packet.recentIssueSignalLabel,
        'recent person activity around Reception',
      );
    },
  );

  test(
    'build preserves line-crossing semantics even when object label is missing',
    () {
      final nowUtc = DateTime.utc(2026, 4, 5, 9, 9);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final recentIntelligence = <IntelligenceReceived>[
        IntelligenceReceived(
          eventId: 'event-line-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-line-1',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-line-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: '11',
          zone: 'Front Gate',
          headline: 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING',
          summary:
              'provider:hikvision_dvr_monitor_only | camera:channel-11 | zone:Front Gate | snapshot:pending',
          riskScore: 84,
          canonicalHash: 'hash-line-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.recentSignals,
      );
      expect(packet.recentMovementObjectLabel, isNull);
      expect(
        packet.recentMovementSignalLabel,
        'recent line-crossing signals around Front Gate',
      );
      expect(
        packet.recentIssueSignalLabel,
        'recent line-crossing signals around Front Gate',
      );
    },
  );

  test(
    'operator issue signal label stays scoped to the matching packet area',
    () {
      final packet = ClientCameraHealthFactPacket(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        status: ClientCameraHealthStatus.limited,
        reason: ClientCameraHealthReason.unknown,
        path: ClientCameraHealthPath.hikConnectApi,
        lastSuccessfulVisualAtUtc: null,
        lastSuccessfulUpstreamProbeAtUtc: null,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        recentIssueSignalLabel:
            'recent line-crossing signals around Front Gate',
        recentMovementHotspotLabel: 'Front Gate',
        nextAction: 'Verify the latest visual path.',
        safeClientExplanation:
            'Live camera visibility at MS Vallee Residence is limited right now.',
      );

      expect(
        packet.operatorIssueSignalLabel(preferredAreaLabel: 'Front Gate'),
        'recent line-crossing signals around Front Gate',
      );
      expect(
        packet.operatorIssueSignalLabel(preferredAreaLabel: 'Perimeter'),
        isNull,
      );
    },
  );

  test(
    'operator issue signal label derives live tactical wording from active issue hotspots',
    () {
      final packet = ClientCameraHealthFactPacket(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        lastSuccessfulVisualAtUtc: DateTime.utc(2026, 4, 5, 9, 12),
        lastSuccessfulUpstreamProbeAtUtc: DateTime.utc(2026, 4, 5, 9, 12),
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.activeSignals,
        recentMovementHotspotLabel: 'Driveway',
        recentMovementObjectLabel: 'vehicle',
        nextAction: 'Keep the current bridge in place.',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      expect(
        packet.operatorIssueSignalLabel(preferredAreaLabel: 'Driveway'),
        'live vehicle activity around Driveway',
      );
    },
  );

  test(
    'build marks site issue state as no confirmed issue when watch coverage is active without movement signals',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 19, 20);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        continuousVisualWatch: MonitoringWatchContinuousVisualScopeSnapshot(
          scopeKey: 'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE',
          status: MonitoringWatchContinuousVisualStatus.active,
          summary:
              'Continuous visual watch remains active across the perimeter baseline.',
          lastSweepAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
          reachableCameraCount: 2,
          baselineReadyCameraCount: 2,
        ),
        nowUtc: nowUtc,
      );

      expect(
        packet.liveSiteMovementStatus,
        ClientLiveSiteMovementStatus.noConfirmedMovement,
      );
      expect(
        packet.liveSiteIssueStatus,
        ClientLiveSiteIssueStatus.noConfirmedIssue,
      );
      expect(packet.hasNoConfirmedSiteIssue, isTrue);
    },
  );

  test(
    'build marks the legacy localhost path as limited when the proxy is online without a fresh upstream success yet',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 20, 40);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: true,
        running: true,
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        localProxyHealth: localProxyHealth,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(packet.reason, ClientCameraHealthReason.unknown);
      expect(packet.status, ClientCameraHealthStatus.limited);
      expect(
        packet.safeClientExplanation,
        equals(
          'I still have site signals for MS Vallee Residence, but I am verifying the latest visual view before I overstate what I can confirm.',
        ),
      );
    },
  );

  test(
    'build does not treat event stream activity alone as live visual access on the legacy localhost path',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 20, 40);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: true,
        running: true,
        lastSuccessAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
      );
      final recentIntelligence = [
        IntelligenceReceived(
          eventId: 'event-bridge-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 1)),
          intelligenceId: 'intel-bridge-1',
          provider: 'hikvision',
          sourceType: 'dvr',
          externalId: 'ext-bridge-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'channel-0',
          headline: 'Video loss inactive',
          summary: 'videoloss alarm inactive from Hikvision alert stream',
          riskScore: 5,
          canonicalHash: 'hash-bridge-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        localProxyHealth: localProxyHealth,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(packet.reason, ClientCameraHealthReason.legacyProxyActive);
      expect(packet.status, ClientCameraHealthStatus.limited);
      expect(packet.lastSuccessfulVisualAtUtc, isNull);
      expect(
        packet.lastSuccessfulUpstreamProbeAtUtc,
        nowUtc.subtract(const Duration(minutes: 1)),
      );
      expect(
        packet.safeClientExplanation,
        equals(
          'I still have site signals for MS Vallee Residence, but I cannot rely on them alone as a clean live view right now.',
        ),
      );
    },
  );

  test(
    'build treats recent upstream DVR recovery signals as limited visibility on a direct recorder path',
    () {
      final nowUtc = DateTime.utc(2026, 4, 5, 18, 58);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://192.168.0.117/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'digest',
        username: 'operator',
        password: 'secret',
        bearerToken: '',
      );
      final recentIntelligence = [
        IntelligenceReceived(
          eventId: 'event-bridge-clear-1',
          sequence: 1,
          version: 1,
          occurredAt: nowUtc.subtract(const Duration(minutes: 2, seconds: 30)),
          intelligenceId: 'intel-bridge-clear-1',
          provider: 'hikvision_dvr_monitor_only',
          sourceType: 'dvr',
          externalId: 'ext-bridge-clear-1',
          clientId: 'CLIENT-MS-VALLEE',
          regionId: 'REGION-JHB',
          siteId: 'SITE-MS-VALLEE-RESIDENCE',
          cameraId: 'channel-0',
          headline: 'HIKVISION_DVR_MONITOR_ONLY VIDEO_LOSS_CLEARED',
          summary: 'camera:channel-0 | videoloss alarm inactive',
          riskScore: 8,
          canonicalHash: 'hash-bridge-clear-1',
        ),
      ];

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        recentIntelligence: recentIntelligence,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.directRecorder);
      expect(packet.reason, ClientCameraHealthReason.unknown);
      expect(packet.status, ClientCameraHealthStatus.limited);
      expect(
        packet.lastSuccessfulUpstreamProbeAtUtc,
        nowUtc.subtract(const Duration(minutes: 2, seconds: 30)),
      );
      expect(
        packet.safeClientExplanation,
        equals(
          'Live camera visibility at MS Vallee Residence is limited right now while I verify the latest view.',
        ),
      );
    },
  );

  test(
    'build treats a healthy quiet direct-recorder bridge as limited visibility instead of offline',
    () {
      final nowUtc = DateTime.utc(2026, 4, 5, 21, 49);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://192.168.0.117/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'digest',
        username: 'operator',
        password: 'secret',
        bearerToken: '',
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        dvrBridgeHealth: DvrBridgeHealthSnapshot(
          lastHealthyAtUtc: nowUtc.subtract(const Duration(seconds: 20)),
        ),
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.directRecorder);
      expect(packet.reason, ClientCameraHealthReason.unknown);
      expect(packet.status, ClientCameraHealthStatus.limited);
      expect(
        packet.lastSuccessfulUpstreamProbeAtUtc,
        nowUtc.subtract(const Duration(seconds: 20)),
      );
      expect(
        packet.safeClientExplanation,
        equals(
          'Live camera visibility at MS Vallee Residence is limited right now while I verify the latest view.',
        ),
      );
    },
  );

  test(
    'build marks the legacy localhost path as live when a current visual probe succeeds',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 20, 40);
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: true,
        running: true,
        lastSuccessAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
      );
      final localVisualProbe = LocalHikvisionDvrVisualProbeSnapshot(
        snapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
        ),
        cameraId: 'channel-1',
        reachable: true,
        verifiedAtUtc: nowUtc.subtract(const Duration(seconds: 30)),
      );
      final localRelayProbe = LocalHikvisionDvrRelayProbeSnapshot(
        streamUri: Uri.parse(
          'http://127.0.0.1:11635/onyx/live/channels/101.mjpg',
        ),
        playerUri: Uri.parse(
          'http://127.0.0.1:11635/onyx/live/channels/101/player',
        ),
        streamReachable: true,
        playerReachable: true,
        checkedAtUtc: nowUtc.subtract(const Duration(seconds: 20)),
        verifiedAtUtc: nowUtc.subtract(const Duration(seconds: 20)),
        relayStatus: ClientCameraRelayStatus.active,
        lastFrameAtUtc: nowUtc.subtract(const Duration(seconds: 4)),
        activeClientCount: 2,
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        localProxyHealth: localProxyHealth,
        localVisualProbe: localVisualProbe,
        localRelayProbe: localRelayProbe,
        nowUtc: nowUtc,
      );

      expect(packet.path, ClientCameraHealthPath.legacyLocalProxy);
      expect(packet.reason, ClientCameraHealthReason.legacyProxyActive);
      expect(packet.status, ClientCameraHealthStatus.live);
      expect(
        packet.lastSuccessfulVisualAtUtc,
        nowUtc.subtract(const Duration(seconds: 30)),
      );
      expect(
        packet.currentVisualSnapshotUri?.toString(),
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
      );
      expect(
        packet.currentVisualRelayStreamUri?.toString(),
        'http://127.0.0.1:11635/onyx/live/channels/101.mjpg',
      );
      expect(
        packet.currentVisualRelayPlayerUri?.toString(),
        'http://127.0.0.1:11635/onyx/live/channels/101/player',
      );
      expect(packet.currentVisualCameraId, 'channel-1');
      expect(
        packet.currentVisualVerifiedAtUtc,
        nowUtc.subtract(const Duration(seconds: 30)),
      );
      expect(packet.safeClientExplanation, contains('visual confirmation'));
      expect(
        packet.safeClientExplanation,
        isNot(contains('live camera access')),
      );
      expect(packet.operatorSummary, contains('stream_relay=ready'));
      expect(packet.operatorSummary, contains('stream_relay_status=active'));
      expect(
        packet.toPromptBlock(),
        contains('- current_visual_stream_relay_ready: true'),
      );
      expect(
        packet.toPromptBlock(),
        contains('- current_visual_stream_relay_status: active'),
      );
      expect(
        packet.toPromptBlock(),
        contains(
          '- current_visual_stream_player_url: http://127.0.0.1:11635/onyx/live/channels/101/player',
        ),
      );
      expect(
        packet.toPromptBlock(),
        contains(
          '- current_visual_stream_relay_checked_utc: 2026-04-03T20:39:40.000Z',
        ),
      );
      expect(
        packet.toPromptBlock(),
        contains(
          '- current_visual_stream_last_frame_utc: 2026-04-03T20:39:56.000Z',
        ),
      );
      expect(
        packet.toPromptBlock(),
        contains('- current_visual_stream_active_clients: 2'),
      );
    },
  );

  test(
    'packet keeps relay failure detail when a current frame is verified but the stream relay is unavailable',
    () {
      final nowUtc = DateTime.utc(2026, 4, 3, 20, 40);
      const service = ClientCameraHealthFactPacketService();
      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_local',
        eventsUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'digest',
        username: 'admin',
        password: 'secret',
        bearerToken: '',
      );
      final localProxyHealth = LocalHikvisionDvrProxyHealthSnapshot(
        healthEndpoint: Uri.parse('http://127.0.0.1:11635/health'),
        reachable: true,
        running: true,
        lastSuccessAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
      );
      final localVisualProbe = LocalHikvisionDvrVisualProbeSnapshot(
        snapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/101/picture',
        ),
        cameraId: 'channel-1',
        reachable: true,
        verifiedAtUtc: nowUtc.subtract(const Duration(seconds: 30)),
      );
      final localRelayProbe = LocalHikvisionDvrRelayProbeSnapshot(
        streamUri: Uri.parse(
          'http://127.0.0.1:11635/onyx/live/channels/101.mjpg',
        ),
        playerUri: Uri.parse(
          'http://127.0.0.1:11635/onyx/live/channels/101/player',
        ),
        streamReachable: false,
        playerReachable: false,
        checkedAtUtc: nowUtc.subtract(const Duration(seconds: 10)),
        relayStatus: ClientCameraRelayStatus.error,
        lastError: 'Relay player HTTP 404',
      );

      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        scope: scope,
        localProxyHealth: localProxyHealth,
        localVisualProbe: localVisualProbe,
        localRelayProbe: localRelayProbe,
        nowUtc: nowUtc,
      );

      expect(packet.hasCurrentVisualConfirmation, isTrue);
      expect(packet.hasCurrentVisualStreamRelay, isFalse);
      expect(
        packet.currentVisualRelayCheckedAtUtc,
        nowUtc.subtract(const Duration(seconds: 10)),
      );
      expect(packet.currentVisualRelayLastError, 'Relay player HTTP 404');
      expect(packet.currentVisualRelayStatus, ClientCameraRelayStatus.error);
      expect(
        packet.toPromptBlock(),
        contains('- current_visual_stream_relay_error: Relay player HTTP 404'),
      );
    },
  );

  test('packet carries continuous visual watch facts into operator context', () {
    final nowUtc = DateTime.utc(2026, 4, 4, 6, 15);
    final packet = service.build(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      siteReference: 'MS Vallee Residence',
      continuousVisualWatch: MonitoringWatchContinuousVisualScopeSnapshot(
        scopeKey: 'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE',
        status: MonitoringWatchContinuousVisualStatus.active,
        lastSweepAtUtc: nowUtc.subtract(const Duration(seconds: 8)),
        lastCandidateAtUtc: nowUtc.subtract(const Duration(minutes: 4)),
        reachableCameraCount: 3,
        baselineReadyCameraCount: 2,
        hotCameraId: 'channel-11',
        hotCameraLabel: 'Perimeter Camera 11',
        hotZoneLabel: 'Perimeter',
        hotAreaLabel: 'Front Gate',
        hotWatchRuleKey: 'perimeter_watch',
        hotWatchPriorityLabel: 'High',
        hotCameraChangeStreakCount: 1,
        hotCameraChangeStage:
            MonitoringWatchContinuousVisualChangeStage.watching,
        hotCameraChangeActiveSinceUtc: nowUtc.subtract(
          const Duration(seconds: 20),
        ),
        hotCameraSceneDeltaScore: 0.417,
        correlatedContextLabel: 'Front Gate',
        correlatedAreaLabel: 'Front Gate',
        correlatedZoneLabel: 'Perimeter',
        correlatedWatchRuleKey: 'perimeter_watch',
        correlatedWatchPriorityLabel: 'High',
        correlatedChangeStage:
            MonitoringWatchContinuousVisualChangeStage.sustained,
        correlatedActiveSinceUtc: nowUtc.subtract(const Duration(seconds: 16)),
        correlatedCameraCount: 2,
        correlatedCameraLabels: const <String>[
          'Front Gate Entry',
          'Front Gate Perimeter',
        ],
        watchPostureKey: 'perimeter_pressure',
        watchPostureLabel: 'Perimeter pressure',
        watchAttentionLabel: 'high',
        watchSourceLabel: 'cross_camera',
        summary:
            'Continuous visual watch still sees a sustained high-priority perimeter pressure near Front Gate across 2 cameras.',
      ),
      nowUtc: nowUtc,
    );

    expect(packet.operatorSummary, contains('continuous_visual_watch=active'));
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_hot_camera=Perimeter Camera 11'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_hot_area=Front Gate'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_hot_priority=High'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_correlated_context=Front Gate'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_posture=Perimeter pressure'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_attention=high'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_correlated_stage=sustained'),
    );
    expect(
      packet.operatorSummary,
      contains('continuous_visual_watch_hot_stage=watching'),
    );
    expect(
      packet.operatorSummary,
      contains(
        'continuous_visual_watch_last_sweep_utc=2026-04-04T06:14:52.000Z',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_status: active'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_summary: Continuous visual watch still sees a sustained high-priority perimeter pressure near Front Gate across 2 cameras.',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_posture_key: perimeter_pressure'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_posture_label: Perimeter pressure'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_attention_label: high'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_source_label: cross_camera'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_reachable_cameras: 3'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_baseline_ready_cameras: 2'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_hot_camera_label: Perimeter Camera 11',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_zone_label: Perimeter'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_area_label: Front Gate'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_watch_rule_key: perimeter_watch'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_watch_priority_label: High'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_camera_streak: 1'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_camera_stage: watching'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_hot_camera_since_utc: 2026-04-04T06:14:40.000Z',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_hot_camera_delta_score: 0.417'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_correlated_context_label: Front Gate',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_correlated_area_label: Front Gate'),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_correlated_zone_label: Perimeter'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_correlated_watch_rule_key: perimeter_watch',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_correlated_watch_priority_label: High',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_correlated_stage: sustained'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_correlated_since_utc: 2026-04-04T06:14:44.000Z',
      ),
    );
    expect(
      packet.toPromptBlock(),
      contains('- continuous_visual_watch_correlated_camera_count: 2'),
    );
    expect(
      packet.toPromptBlock(),
      contains(
        '- continuous_visual_watch_correlated_camera_labels: Front Gate Entry, Front Gate Perimeter',
      ),
    );
  });

  test(
    'packet exposes continuous visual watch activity helpers for resident routing',
    () {
      final nowUtc = DateTime.utc(2026, 4, 4, 6, 15);
      final packet = service.build(
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        siteReference: 'MS Vallee Residence',
        continuousVisualWatch: MonitoringWatchContinuousVisualScopeSnapshot(
          scopeKey: 'CLIENT-MS-VALLEE|SITE-MS-VALLEE-RESIDENCE',
          status: MonitoringWatchContinuousVisualStatus.alerting,
          lastSweepAtUtc: nowUtc.subtract(const Duration(seconds: 8)),
          lastCandidateAtUtc: nowUtc.subtract(const Duration(seconds: 4)),
          hotCameraLabel: 'Perimeter Camera 11',
          hotAreaLabel: 'Front Gate',
          hotCameraChangeStage:
              MonitoringWatchContinuousVisualChangeStage.persistent,
          correlatedContextLabel: 'Front Gate',
          correlatedChangeStage:
              MonitoringWatchContinuousVisualChangeStage.sustained,
        ),
        nowUtc: nowUtc,
      );

      expect(packet.hasContinuousVisualCoverage, isTrue);
      expect(packet.hasActiveContinuousVisualChange, isTrue);
      expect(packet.hasOngoingContinuousVisualChange, isTrue);
      expect(packet.continuousVisualHotspotLabel, 'Front Gate');
    },
  );

  test(
    'local relay probe verifies the MJPEG relay and player endpoints',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/onyx/live/channels/101.mjpg') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'multipart/x-mixed-replace; boundary=onyxframe',
          );
          await request.response.close();
          return;
        }
        if (request.uri.path == '/onyx/live/channels/101/player') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/html; charset=utf-8',
          );
          await request.response.close();
          return;
        }
        if (request.uri.path == '/onyx/live/channels/101/status') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.response.write(
            jsonEncode(<String, Object?>{
              'ok': true,
              'stream_id': '101',
              'status': 'ready',
              'active_clients': 1,
              'last_frame_at_utc': '2026-04-03T20:39:58.000Z',
              'last_error': '',
            }),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final probeService = HttpLocalHikvisionDvrRelayProbeService(
        client: http.Client(),
      );
      final visualProbe = LocalHikvisionDvrVisualProbeSnapshot(
        snapshotUri: Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Streaming/channels/101/picture',
        ),
        cameraId: 'channel-1',
        reachable: true,
        verifiedAtUtc: DateTime.utc(2026, 4, 3, 20, 40),
      );

      final relayProbe = await probeService.read(visualProbe);

      expect(relayProbe, isNotNull);
      expect(relayProbe!.ready, isTrue);
      expect(
        relayProbe.streamUri.toString(),
        'http://127.0.0.1:${server.port}/onyx/live/channels/101.mjpg',
      );
      expect(
        relayProbe.playerUri.toString(),
        'http://127.0.0.1:${server.port}/onyx/live/channels/101/player',
      );
      expect(
        relayProbe.statusUri.toString(),
        'http://127.0.0.1:${server.port}/onyx/live/channels/101/status',
      );
      expect(relayProbe.relayStatus, ClientCameraRelayStatus.ready);
      expect(relayProbe.activeClientCount, 1);
      expect(relayProbe.lastFrameAtUtc, DateTime.utc(2026, 4, 3, 20, 39, 58));
      expect(relayProbe.checkedAtUtc, isNotNull);
      expect(relayProbe.verifiedAtUtc, isNotNull);
    },
  );

  test(
    'local proxy health service parses upstream connection and buffered alert metadata',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/health') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.response.write(
            jsonEncode(<String, Object?>{
              'status': 'ok',
              'running': true,
              'endpoint': 'http://127.0.0.1:${server.port}',
              'upstream_alert_stream':
                  'http://192.168.0.117/ISAPI/Event/notification/alertStream',
              'upstream_stream_connected': true,
              'buffered_alert_count': 4,
              'last_alert_at_utc': '2026-04-05T06:21:12.000Z',
              'last_success_at_utc': '2026-04-05T06:21:20.000Z',
              'last_error': '',
            }),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final healthService = HttpLocalHikvisionDvrProxyHealthService(
        client: http.Client(),
      );

      final snapshot = await healthService.read(
        Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Event/notification/alertStream',
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.reachable, isTrue);
      expect(snapshot.running, isTrue);
      expect(
        snapshot.proxyEndpoint.toString(),
        'http://127.0.0.1:${server.port}',
      );
      expect(
        snapshot.upstreamAlertStreamUri.toString(),
        'http://192.168.0.117/ISAPI/Event/notification/alertStream',
      );
      expect(snapshot.upstreamStreamConnected, isTrue);
      expect(snapshot.bufferedAlertCount, 4);
      expect(snapshot.lastAlertAtUtc, DateTime.utc(2026, 4, 5, 6, 21, 12));
      expect(snapshot.lastSuccessAtUtc, DateTime.utc(2026, 4, 5, 6, 21, 20));
      expect(snapshot.lastError, isEmpty);
    },
  );

  test(
    'local proxy health service parses reconnecting upstream state',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/health') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json; charset=utf-8',
          );
          request.response.write(
            jsonEncode(<String, Object?>{
              'status': 'ok',
              'running': true,
              'endpoint': 'http://127.0.0.1:${server.port}',
              'upstream_alert_stream':
                  'http://192.168.0.117/ISAPI/Event/notification/alertStream',
              'upstream_stream_status': 'reconnecting',
              'upstream_stream_connected': false,
              'buffered_alert_count': 2,
              'last_alert_at_utc': '2026-04-05T06:21:12.000Z',
              'last_success_at_utc': '2026-04-05T06:21:20.000Z',
              'last_error': '',
            }),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final healthService = HttpLocalHikvisionDvrProxyHealthService(
        client: http.Client(),
      );

      final snapshot = await healthService.read(
        Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Event/notification/alertStream',
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.reachable, isTrue);
      expect(snapshot.running, isTrue);
      expect(snapshot.upstreamStreamStatus, 'reconnecting');
      expect(snapshot.upstreamStreamConnected, isFalse);
      expect(snapshot.bufferedAlertCount, 2);
    },
  );

  test(
    'local visual probe verifies a current Hikvision snapshot through the proxy',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/ISAPI/Streaming/channels/101/picture') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'image/jpeg',
          );
          if (request.method == 'GET') {
            request.response.add(const <int>[1, 2, 3]);
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final probeService = HttpLocalHikvisionDvrVisualProbeService(
        client: http.Client(),
      );

      final snapshot = await probeService.read(scope);

      expect(snapshot, isNotNull);
      expect(snapshot!.reachable, isTrue);
      expect(snapshot.cameraId, 'channel-1');
      expect(snapshot.verifiedAtUtc, isNotNull);
      expect(
        snapshot.snapshotUri.toString(),
        'http://127.0.0.1:${server.port}/ISAPI/Streaming/channels/101/picture',
      );
    },
  );

  test(
    'local visual probe prefers recent scoped channel hints and can verify channel 16 snapshots',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/ISAPI/Streaming/channels/1601/picture') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'image/jpeg',
          );
          if (request.method == 'GET') {
            request.response.add(const <int>[1, 2, 3]);
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final probeService = HttpLocalHikvisionDvrVisualProbeService(
        client: http.Client(),
      );

      final snapshot = await probeService.read(
        scope,
        recentIntelligence: <IntelligenceReceived>[
          IntelligenceReceived(
            eventId: 'event-channel-16',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 5, 19, 7, 25),
            intelligenceId: 'intel-channel-16',
            provider: 'hikvision_dvr',
            sourceType: 'dvr',
            externalId: 'ext-channel-16',
            clientId: 'CLIENT-MS-VALLEE',
            regionId: 'REGION-JHB',
            siteId: 'SITE-MS-VALLEE-RESIDENCE',
            cameraId: 'channel-16',
            headline: 'Motion alarm',
            summary: 'Human motion detected on channel 16.',
            riskScore: 40,
            canonicalHash: 'hash-channel-16',
          ),
        ],
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.reachable, isTrue);
      expect(snapshot.cameraId, 'channel-16');
      expect(snapshot.verifiedAtUtc, isNotNull);
      expect(
        snapshot.snapshotUri.toString(),
        'http://127.0.0.1:${server.port}/ISAPI/Streaming/channels/1601/picture',
      );
    },
  );

  test(
    'local visual probe ignores recent channel hints from other scopes',
    () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((request) async {
        if (request.uri.path == '/ISAPI/Streaming/channels/101/picture') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'image/jpeg',
          );
          if (request.method == 'GET') {
            request.response.add(const <int>[1, 2, 3]);
          }
          await request.response.close();
          return;
        }
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
      });

      final scope = DvrScopeConfig(
        clientId: 'CLIENT-MS-VALLEE',
        regionId: 'REGION-JHB',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        provider: 'hikvision_dvr_monitor_only',
        eventsUri: Uri.parse(
          'http://127.0.0.1:${server.port}/ISAPI/Event/notification/alertStream',
        ),
        authMode: 'none',
        username: '',
        password: '',
        bearerToken: '',
      );
      final probeService = HttpLocalHikvisionDvrVisualProbeService(
        client: http.Client(),
      );

      final snapshot = await probeService.read(
        scope,
        recentIntelligence: <IntelligenceReceived>[
          IntelligenceReceived(
            eventId: 'event-other-scope',
            sequence: 1,
            version: 1,
            occurredAt: DateTime.utc(2026, 4, 5, 19, 7, 25),
            intelligenceId: 'intel-other-scope',
            provider: 'hikvision_dvr',
            sourceType: 'dvr',
            externalId: 'ext-other-scope',
            clientId: 'CLIENT-OTHER',
            regionId: 'REGION-JHB',
            siteId: 'SITE-OTHER',
            cameraId: 'channel-16',
            headline: 'Motion alarm',
            summary: 'Human motion detected on another site.',
            riskScore: 40,
            canonicalHash: 'hash-other-scope',
          ),
        ],
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.reachable, isTrue);
      expect(snapshot.cameraId, 'channel-1');
      expect(snapshot.verifiedAtUtc, isNotNull);
      expect(
        snapshot.snapshotUri.toString(),
        'http://127.0.0.1:${server.port}/ISAPI/Streaming/channels/101/picture',
      );
    },
  );
}
