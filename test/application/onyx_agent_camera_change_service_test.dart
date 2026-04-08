import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:omnix_dashboard/application/dispatch_persistence_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_change_service.dart';

class _FakeExecutor implements OnyxAgentCameraDeviceExecutor {
  const _FakeExecutor();

  @override
  bool get isConfigured => true;

  @override
  String get modeLabel => 'LAN bridge';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    return OnyxAgentCameraExecutionOutcome(
      success: true,
      providerLabel: 'lan:test-camera-executor',
      detail:
          'Bridge applied the approved profile and returned a confirmation payload.',
      recommendedNextStep:
          'Validate the feed in CCTV and confirm recorder ingest.',
      remoteExecutionId: 'REMOTE-EXEC-42',
      recordedAtUtc: DateTime.utc(2026, 3, 27, 8, 15),
    );
  }
}

class _ThrowingExecutor implements OnyxAgentCameraDeviceExecutor {
  const _ThrowingExecutor();

  @override
  bool get isConfigured => true;

  @override
  String get modeLabel => 'LAN bridge';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) {
    throw StateError('bridge offline');
  }
}

OnyxAgentCameraExecutionPacket _testExecutionPacket({
  required String packetId,
  required String target,
  String vendorKey = 'hikvision',
  String vendorLabel = 'Hikvision',
  String profileKey = 'alarm_verification',
  String profileLabel = 'Alarm Verification',
}) {
  return OnyxAgentCameraExecutionPacket(
    packetId: packetId,
    target: target,
    vendorKey: vendorKey,
    vendorLabel: vendorLabel,
    profileKey: profileKey,
    profileLabel: profileLabel,
    onvifProfileToken: 'onyx-hik-alarm-verification',
    mainStreamLabel: 'H.265 2560x1440 @ 18 fps / 3072 kbps',
    subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
    recorderTarget: 'alarm_review_nvr',
    rollbackExportLabel: 'rollback-$packetId-192-168-1-64.json',
    credentialHandling: 'Keep device credentials local.',
  );
}

void main() {
  group('LocalOnyxAgentCameraChangeService', () {
    test(
      'stages approval-gated camera change summary for scoped target',
      () async {
        const service = LocalOnyxAgentCameraChangeService();

        final result = await service.stage(
          target: '192.168.1.64',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-42',
          sourceRouteLabel: 'AI Queue',
        );

        expect(result.packetId, startsWith('CAM-PKT-'));
        expect(result.target, '192.168.1.64');
        expect(result.scopeLabel, 'CLIENT-001 • SITE-SANDTON');
        expect(result.providerLabel, 'local:camera-change-stage');
        expect(result.executionPacket.vendorLabel, 'Generic ONVIF');
        expect(result.executionPacket.profileLabel, 'Balanced Monitoring');
        expect(
          result.executionPacket.rollbackExportLabel,
          contains(result.packetId),
        );
        expect(
          result.toOperatorSummary(),
          contains('Approval gate: staged only'),
        );
        expect(result.toOperatorSummary(), contains('Change packet:'));
        expect(result.toOperatorSummary(), contains('Worker packet:'));
        expect(
          result.toOperatorSummary(),
          contains('Restore the previous stream/profile'),
        );
      },
    );

    test('falls back to scoped target label when target is empty', () async {
      const service = LocalOnyxAgentCameraChangeService();

      final result = await service.stage(
        target: '',
        clientId: '',
        siteId: '',
        incidentReference: '',
        sourceRouteLabel: '',
      );

      expect(result.target, 'current scoped camera target');
      expect(result.scopeLabel, 'Global controller scope');
      expect(result.sourceRouteLabel, 'Command');
      expect(service.executionModeLabel, 'Embedded camera bridge (staging)');
    });

    test('approves and executes a staged camera packet', () async {
      const service = LocalOnyxAgentCameraChangeService();

      final result = await service.approveAndExecute(
        packetId: 'CAM-PKT-123',
        target: '192.168.1.64',
        clientId: 'CLIENT-001',
        siteId: 'SITE-SANDTON',
        incidentReference: 'INC-CTRL-42',
      );

      expect(result.packetId, 'CAM-PKT-123');
      expect(result.executionId, startsWith('CAM-EXEC-'));
      expect(result.success, isTrue);
      expect(result.executionPacket.profileLabel, 'Balanced Monitoring');
      expect(result.toOperatorSummary(), contains('Approved and executed'));
      expect(result.toOperatorSummary(), contains('Execution audit:'));
    });

    test('logs rollback against an executed packet', () async {
      const service = LocalOnyxAgentCameraChangeService();

      final result = await service.logRollback(
        packetId: 'CAM-PKT-123',
        executionId: 'CAM-EXEC-456',
        target: '192.168.1.64',
      );

      expect(result.packetId, 'CAM-PKT-123');
      expect(result.executionId, 'CAM-EXEC-456');
      expect(result.rollbackId, startsWith('CAM-RBK-'));
      expect(result.executionPacket.rollbackExportLabel, contains('rollback-'));
      expect(result.toOperatorSummary(), contains('Rollback audit:'));
      expect(
        result.toOperatorSummary(),
        contains('Previous stream/profile restored'),
      );
    });
  });

  group('PersistedOnyxAgentCameraChangeService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test(
      'persists staged execution and rollback audit history for scope',
      () async {
        final service = PersistedOnyxAgentCameraChangeService(
          persistenceFuture: DispatchPersistenceService.create(),
          executor: const _FakeExecutor(),
        );

        final stage = await service.stage(
          target: '192.168.1.64',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-42',
          sourceRouteLabel: 'AI Queue',
        );
        final execution = await service.approveAndExecute(
          packetId: stage.packetId,
          target: stage.target,
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-42',
        );
        final rollback = await service.logRollback(
          packetId: stage.packetId,
          executionId: execution.executionId,
          target: execution.target,
        );

        final history = await service.readAuditHistory(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-42',
        );

        expect(service.executionModeLabel, 'LAN bridge');
        expect(history, hasLength(3));
        final rollbackEntry = history.firstWhere(
          (entry) => entry.kind == OnyxAgentCameraAuditKind.rolledBack,
        );
        final executionEntry = history.firstWhere(
          (entry) => entry.kind == OnyxAgentCameraAuditKind.executed,
        );
        final stagedEntry = history.firstWhere(
          (entry) => entry.kind == OnyxAgentCameraAuditKind.staged,
        );
        expect(rollbackEntry.rollbackId, rollback.rollbackId);
        expect(executionEntry.executionId, execution.executionId);
        expect(executionEntry.providerLabel, 'lan:test-camera-executor');
        expect(executionEntry.detail, contains('Bridge applied'));
        expect(stagedEntry.packetId, stage.packetId);
        expect(stagedEntry.vendorLabel, 'Generic ONVIF');
        expect(stagedEntry.profileLabel, 'Balanced Monitoring');
        expect(rollbackEntry.rollbackExportLabel, contains('rollback-'));
      },
    );

    test(
      'captures executor failures without throwing and persists follow-up audit',
      () async {
        final service = PersistedOnyxAgentCameraChangeService(
          persistenceFuture: DispatchPersistenceService.create(),
          executor: const _ThrowingExecutor(),
        );

        final stage = await service.stage(
          target: '192.168.1.91',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-77',
          sourceRouteLabel: 'Command',
        );
        final result = await service.approveAndExecute(
          packetId: stage.packetId,
          target: stage.target,
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-77',
        );

        final history = await service.readAuditHistory(
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          incidentReference: 'INC-CTRL-77',
        );

        expect(result.success, isFalse);
        expect(
          result.toOperatorSummary(),
          contains('Execution did not confirm cleanly'),
        );
        expect(history.first.kind, OnyxAgentCameraAuditKind.executed);
        expect(history.first.success, isFalse);
        expect(history.first.statusLabel, 'follow-up required');
        expect(history.first.detail, contains('bridge offline'));
        expect(history.first.profileLabel, 'Alarm Verification');
      },
    );
  });

  group('HttpOnyxAgentCameraDeviceExecutor', () {
    test(
      'posts approved packet to the LAN bridge and parses success payload',
      () async {
        late Uri capturedUri;
        late Map<String, Object?> capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'provider_label': 'lan:bridge',
              'detail': 'Applied the approved camera profile.',
              'next_step': 'Confirm stream quality in CCTV.',
              'execution_id': 'REMOTE-100',
              'executed_at_utc': '2026-03-27T08:30:00Z',
            }),
            200,
          );
        });
        final executor = HttpOnyxAgentCameraDeviceExecutor(
          client: client,
          endpoint: Uri.parse('http://127.0.0.1:8787/camera/execute'),
          authToken: 'secret',
        );

        final outcome = await executor.execute(
          OnyxAgentCameraExecutionRequest(
            packetId: 'CAM-PKT-1',
            target: '192.168.1.64',
            clientId: 'CLIENT-001',
            siteId: 'SITE-SANDTON',
            scopeLabel: 'CLIENT-001 • SITE-SANDTON',
            incidentReference: 'INC-CTRL-42',
            sourceRouteLabel: 'AI Queue',
            approvedAtUtc: DateTime.utc(2026, 3, 27, 8, 29),
            executionPacket: _testExecutionPacket(
              packetId: 'CAM-PKT-1',
              target: '192.168.1.64',
            ),
          ),
        );

        expect(capturedUri.toString(), 'http://127.0.0.1:8787/camera/execute');
        expect(capturedBody['packet_id'], 'CAM-PKT-1');
        expect(capturedBody['target'], '192.168.1.64');
        expect(capturedBody['execution_packet'], isA<Map>());
        final packet =
            capturedBody['execution_packet']! as Map<String, Object?>;
        expect(packet['vendor_label'], 'Hikvision');
        expect(packet['profile_label'], 'Alarm Verification');
        expect(packet['rollback_export_label'], contains('rollback-CAM-PKT-1'));
        expect(outcome.success, isTrue);
        expect(outcome.providerLabel, 'lan:bridge');
        expect(outcome.remoteExecutionId, 'REMOTE-100');
        expect(outcome.detail, contains('Applied the approved camera profile'));
      },
    );

    test('turns non-2xx bridge responses into failed outcomes', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'detail': 'Authentication failed at the bridge.',
            'next_step': 'Check credentials and retry locally.',
          }),
          503,
        );
      });
      final executor = HttpOnyxAgentCameraDeviceExecutor(
        client: client,
        endpoint: Uri.parse('http://127.0.0.1:8787/camera/execute'),
      );

      final outcome = await executor.execute(
        OnyxAgentCameraExecutionRequest(
          packetId: 'CAM-PKT-1',
          target: '192.168.1.64',
          clientId: 'CLIENT-001',
          siteId: 'SITE-SANDTON',
          scopeLabel: 'CLIENT-001 • SITE-SANDTON',
          incidentReference: 'INC-CTRL-42',
          sourceRouteLabel: 'AI Queue',
          approvedAtUtc: DateTime.utc(2026, 3, 27, 8, 29),
          executionPacket: _testExecutionPacket(
            packetId: 'CAM-PKT-1',
            target: '192.168.1.64',
          ),
        ),
      );

      expect(outcome.success, isFalse);
      expect(outcome.providerLabel, 'lan:http-camera-executor');
      expect(outcome.detail, contains('Executor bridge HTTP 503'));
      expect(outcome.recommendedNextStep, contains('Check credentials'));
    });
  });
}
