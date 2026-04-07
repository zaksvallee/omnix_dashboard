import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dispatch_persistence_service.dart';

enum OnyxAgentCameraAuditKind { staged, executed, rolledBack }

class OnyxAgentCameraExecutionPacket {
  final String packetId;
  final String target;
  final String vendorKey;
  final String vendorLabel;
  final String profileKey;
  final String profileLabel;
  final String onvifProfileToken;
  final String mainStreamLabel;
  final String subStreamLabel;
  final String recorderTarget;
  final String rollbackExportLabel;
  final String credentialHandling;
  final List<String> changePlan;
  final List<String> verificationPlan;
  final List<String> rollbackPlan;

  const OnyxAgentCameraExecutionPacket({
    required this.packetId,
    required this.target,
    required this.vendorKey,
    required this.vendorLabel,
    required this.profileKey,
    required this.profileLabel,
    required this.onvifProfileToken,
    required this.mainStreamLabel,
    required this.subStreamLabel,
    required this.recorderTarget,
    required this.rollbackExportLabel,
    required this.credentialHandling,
    this.changePlan = const <String>[],
    this.verificationPlan = const <String>[],
    this.rollbackPlan = const <String>[],
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'packet_id': packetId,
      'target': target,
      'vendor_key': vendorKey,
      'vendor_label': vendorLabel,
      'profile_key': profileKey,
      'profile_label': profileLabel,
      'onvif_profile_token': onvifProfileToken,
      'main_stream_label': mainStreamLabel,
      'sub_stream_label': subStreamLabel,
      'recorder_target': recorderTarget,
      'rollback_export_label': rollbackExportLabel,
      'credential_handling': credentialHandling,
      'change_plan': changePlan,
      'verification_plan': verificationPlan,
      'rollback_plan': rollbackPlan,
    };
  }

  static OnyxAgentCameraExecutionPacket? fromJson(Map<String, Object?> json) {
    final packetId = _stringValue(json['packet_id']);
    final target = _stringValue(json['target']);
    final vendorKey = _stringValue(json['vendor_key']);
    final vendorLabel = _stringValue(json['vendor_label']);
    final profileKey = _stringValue(json['profile_key']);
    final profileLabel = _stringValue(json['profile_label']);
    final onvifProfileToken = _stringValue(json['onvif_profile_token']);
    final mainStreamLabel = _stringValue(json['main_stream_label']);
    final subStreamLabel = _stringValue(json['sub_stream_label']);
    final recorderTarget = _stringValue(json['recorder_target']);
    final rollbackExportLabel = _stringValue(json['rollback_export_label']);
    final credentialHandling = _stringValue(json['credential_handling']);
    if (packetId.isEmpty ||
        target.isEmpty ||
        vendorKey.isEmpty ||
        vendorLabel.isEmpty ||
        profileKey.isEmpty ||
        profileLabel.isEmpty ||
        onvifProfileToken.isEmpty ||
        mainStreamLabel.isEmpty ||
        subStreamLabel.isEmpty ||
        recorderTarget.isEmpty ||
        rollbackExportLabel.isEmpty ||
        credentialHandling.isEmpty) {
      return null;
    }
    return OnyxAgentCameraExecutionPacket(
      packetId: packetId,
      target: target,
      vendorKey: vendorKey,
      vendorLabel: vendorLabel,
      profileKey: profileKey,
      profileLabel: profileLabel,
      onvifProfileToken: onvifProfileToken,
      mainStreamLabel: mainStreamLabel,
      subStreamLabel: subStreamLabel,
      recorderTarget: recorderTarget,
      rollbackExportLabel: rollbackExportLabel,
      credentialHandling: credentialHandling,
      changePlan: _stringListValue(json['change_plan']),
      verificationPlan: _stringListValue(json['verification_plan']),
      rollbackPlan: _stringListValue(json['rollback_plan']),
    );
  }

  String toOperatorSummary() {
    final buffer = StringBuffer()
      ..writeln('Worker packet:')
      ..writeln('- Vendor worker: $vendorLabel')
      ..writeln('- Applied preset: $profileLabel ($profileKey)')
      ..writeln('- ONVIF profile token: $onvifProfileToken')
      ..writeln('- Main stream: $mainStreamLabel')
      ..writeln('- Substream: $subStreamLabel')
      ..writeln('- Recorder target: $recorderTarget')
      ..writeln('- Rollback export: $rollbackExportLabel')
      ..writeln('- Credentials: $credentialHandling');
    if (changePlan.isNotEmpty) {
      buffer.writeln('Change plan:');
      for (final step in changePlan) {
        buffer.writeln('- $step');
      }
    }
    if (verificationPlan.isNotEmpty) {
      buffer.writeln('Verification:');
      for (final step in verificationPlan) {
        buffer.writeln('- $step');
      }
    }
    if (rollbackPlan.isNotEmpty) {
      buffer.writeln('Rollback plan:');
      for (final step in rollbackPlan) {
        buffer.writeln('- $step');
      }
    }
    return buffer.toString().trimRight();
  }
}

class OnyxAgentCameraAuditEntry {
  final String auditId;
  final OnyxAgentCameraAuditKind kind;
  final String packetId;
  final String executionId;
  final String rollbackId;
  final String target;
  final String clientId;
  final String siteId;
  final String scopeLabel;
  final String incidentReference;
  final String sourceRouteLabel;
  final String providerLabel;
  final String statusLabel;
  final String detail;
  final bool success;
  final DateTime recordedAtUtc;
  final OnyxAgentCameraExecutionPacket? executionPacket;

  const OnyxAgentCameraAuditEntry({
    required this.auditId,
    required this.kind,
    required this.packetId,
    this.executionId = '',
    this.rollbackId = '',
    required this.target,
    this.clientId = '',
    this.siteId = '',
    required this.scopeLabel,
    this.incidentReference = '',
    this.sourceRouteLabel = 'Command',
    required this.providerLabel,
    required this.statusLabel,
    required this.detail,
    required this.success,
    required this.recordedAtUtc,
    this.executionPacket,
  });

  String get kindLabel {
    switch (kind) {
      case OnyxAgentCameraAuditKind.staged:
        return 'Staged';
      case OnyxAgentCameraAuditKind.executed:
        return success ? 'Executed' : 'Follow-up';
      case OnyxAgentCameraAuditKind.rolledBack:
        return 'Rollback';
    }
  }

  String get vendorLabel => executionPacket?.vendorLabel ?? '';

  String get profileLabel => executionPacket?.profileLabel ?? '';

  String get rollbackExportLabel => executionPacket?.rollbackExportLabel ?? '';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'audit_id': auditId,
      'kind': kind.name,
      'packet_id': packetId,
      'execution_id': executionId,
      'rollback_id': rollbackId,
      'target': target,
      'client_id': clientId,
      'site_id': siteId,
      'scope_label': scopeLabel,
      'incident_reference': incidentReference,
      'source_route_label': sourceRouteLabel,
      'provider_label': providerLabel,
      'status_label': statusLabel,
      'detail': detail,
      'success': success,
      'recorded_at_utc': recordedAtUtc.toIso8601String(),
      'execution_packet': executionPacket?.toJson(),
    };
  }

  static OnyxAgentCameraAuditEntry? fromJson(Map<String, Object?> json) {
    final auditId = _stringValue(json['audit_id']);
    final packetId = _stringValue(json['packet_id']);
    final target = _stringValue(json['target']);
    final providerLabel = _stringValue(json['provider_label']);
    final statusLabel = _stringValue(json['status_label']);
    final detail = _stringValue(json['detail']);
    final recordedAtUtc = _dateValue(json['recorded_at_utc']);
    if (auditId.isEmpty ||
        packetId.isEmpty ||
        target.isEmpty ||
        providerLabel.isEmpty ||
        statusLabel.isEmpty ||
        detail.isEmpty ||
        recordedAtUtc == null) {
      return null;
    }
    final packetRaw = json['execution_packet'];
    final executionPacket = packetRaw is Map
        ? OnyxAgentCameraExecutionPacket.fromJson(
            packetRaw.map(
              (key, value) => MapEntry(key.toString(), value as Object?),
            ),
          )
        : null;
    return OnyxAgentCameraAuditEntry(
      auditId: auditId,
      kind: _auditKindValue(json['kind']),
      packetId: packetId,
      executionId: _stringValue(json['execution_id']),
      rollbackId: _stringValue(json['rollback_id']),
      target: target,
      clientId: _stringValue(json['client_id']),
      siteId: _stringValue(json['site_id']),
      scopeLabel: _stringValue(json['scope_label']),
      incidentReference: _stringValue(json['incident_reference']),
      sourceRouteLabel: _sourceRouteLabel(
        _stringValue(json['source_route_label']),
      ),
      providerLabel: providerLabel,
      statusLabel: statusLabel,
      detail: detail,
      success: _boolValue(json['success']) ?? true,
      recordedAtUtc: recordedAtUtc,
      executionPacket: executionPacket,
    );
  }
}

class OnyxAgentCameraChangePlanResult {
  final String packetId;
  final String target;
  final String scopeLabel;
  final String incidentReference;
  final String sourceRouteLabel;
  final String providerLabel;
  final DateTime createdAtUtc;
  final OnyxAgentCameraExecutionPacket executionPacket;

  const OnyxAgentCameraChangePlanResult({
    required this.packetId,
    required this.target,
    required this.scopeLabel,
    required this.incidentReference,
    required this.sourceRouteLabel,
    this.providerLabel = 'local:camera-change-stage',
    required this.createdAtUtc,
    required this.executionPacket,
  });

  String toOperatorSummary() {
    final incidentLabel = incidentReference.trim().isEmpty
        ? 'No incident pinned'
        : incidentReference.trim();
    return 'Change packet: $packetId\n'
        'Target: $target\n'
        'Scope: $scopeLabel\n'
        'Origin: $sourceRouteLabel\n'
        'Incident: $incidentLabel\n'
        'Approval gate: staged only. No device write has been executed.\n'
        '${executionPacket.toOperatorSummary()}\n'
        'Packet created: ${createdAtUtc.toIso8601String()}\n'
        'Source: $providerLabel';
  }
}

class OnyxAgentCameraExecutionResult {
  final String packetId;
  final String executionId;
  final String remoteExecutionId;
  final String target;
  final String scopeLabel;
  final String incidentReference;
  final String providerLabel;
  final DateTime approvedAtUtc;
  final bool success;
  final String outcomeDetail;
  final String recommendedNextStep;
  final OnyxAgentCameraExecutionPacket executionPacket;

  const OnyxAgentCameraExecutionResult({
    required this.packetId,
    required this.executionId,
    this.remoteExecutionId = '',
    required this.target,
    required this.scopeLabel,
    required this.incidentReference,
    this.providerLabel = 'local:camera-change-executor',
    required this.approvedAtUtc,
    this.success = true,
    this.outcomeDetail =
        'The approved camera profile change was applied locally and still needs immediate CCTV validation.',
    this.recommendedNextStep =
        'Recheck live view, recorder ingest, and client-visible quality in CCTV now.',
    required this.executionPacket,
  });

  String toOperatorSummary() {
    final incidentLabel = incidentReference.trim().isEmpty
        ? 'No incident pinned'
        : incidentReference.trim();
    final statusLabel = success
        ? 'Approved and executed'
        : 'Execution did not confirm cleanly';
    final remoteLabel = remoteExecutionId.trim().isEmpty
        ? 'local audit only'
        : remoteExecutionId.trim();
    return 'Execution packet: $packetId\n'
        'Execution audit: $executionId\n'
        'Executor reference: $remoteLabel\n'
        'Target: $target\n'
        'Scope: $scopeLabel\n'
        'Incident: $incidentLabel\n'
        'Status: $statusLabel\n'
        'Vendor worker: ${executionPacket.vendorLabel}\n'
        'Applied preset: ${executionPacket.profileLabel}\n'
        'Rollback export: ${executionPacket.rollbackExportLabel}\n'
        'Executor detail: $outcomeDetail\n'
        'Next step: $recommendedNextStep\n'
        'Approved at: ${approvedAtUtc.toIso8601String()}\n'
        'Source: $providerLabel';
  }
}

class OnyxAgentCameraRollbackResult {
  final String packetId;
  final String executionId;
  final String rollbackId;
  final String target;
  final String scopeLabel;
  final String incidentReference;
  final String providerLabel;
  final DateTime recordedAtUtc;
  final OnyxAgentCameraExecutionPacket executionPacket;

  const OnyxAgentCameraRollbackResult({
    required this.packetId,
    required this.executionId,
    required this.rollbackId,
    required this.target,
    this.scopeLabel = 'Global controller scope',
    this.incidentReference = '',
    this.providerLabel = 'local:camera-change-rollback',
    required this.recordedAtUtc,
    required this.executionPacket,
  });

  String toOperatorSummary() {
    final incidentLabel = incidentReference.trim().isEmpty
        ? 'No incident pinned'
        : incidentReference.trim();
    return 'Execution packet: $packetId\n'
        'Execution audit: $executionId\n'
        'Rollback audit: $rollbackId\n'
        'Target: $target\n'
        'Scope: $scopeLabel\n'
        'Incident: $incidentLabel\n'
        'Vendor worker: ${executionPacket.vendorLabel}\n'
        'Rollback export: ${executionPacket.rollbackExportLabel}\n'
        'Rollback logged:\n'
        '- Previous stream/profile restored.\n'
        '- Operator should recheck live view and recorder ingest.\n'
        '- Keep the camera packet attached to the incident for follow-up.\n'
        'Recorded at: ${recordedAtUtc.toIso8601String()}\n'
        'Source: $providerLabel';
  }
}

class OnyxAgentCameraExecutionRequest {
  final String packetId;
  final String target;
  final String clientId;
  final String siteId;
  final String scopeLabel;
  final String incidentReference;
  final String sourceRouteLabel;
  final DateTime approvedAtUtc;
  final OnyxAgentCameraExecutionPacket executionPacket;

  const OnyxAgentCameraExecutionRequest({
    required this.packetId,
    required this.target,
    required this.clientId,
    required this.siteId,
    required this.scopeLabel,
    required this.incidentReference,
    required this.sourceRouteLabel,
    required this.approvedAtUtc,
    required this.executionPacket,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'packet_id': packetId,
      'target': target,
      'client_id': clientId,
      'site_id': siteId,
      'scope_label': scopeLabel,
      'incident_reference': incidentReference,
      'source_route_label': sourceRouteLabel,
      'approved_at_utc': approvedAtUtc.toIso8601String(),
      'execution_packet': executionPacket.toJson(),
    };
  }

  static OnyxAgentCameraExecutionRequest? fromJson(Map<String, Object?> json) {
    final packetId = _stringValue(json['packet_id']);
    final target = _stringValue(json['target']);
    final scopeLabel = _stringValue(json['scope_label']);
    final sourceRouteLabel = _stringValue(json['source_route_label']);
    final approvedAtUtc = _dateValue(json['approved_at_utc']);
    final packetRaw = json['execution_packet'];
    if (packetId.isEmpty ||
        target.isEmpty ||
        scopeLabel.isEmpty ||
        sourceRouteLabel.isEmpty ||
        approvedAtUtc == null ||
        packetRaw is! Map) {
      return null;
    }
    final executionPacket = OnyxAgentCameraExecutionPacket.fromJson(
      packetRaw.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
    if (executionPacket == null) {
      return null;
    }
    return OnyxAgentCameraExecutionRequest(
      packetId: packetId,
      target: target,
      clientId: _stringValue(json['client_id']),
      siteId: _stringValue(json['site_id']),
      scopeLabel: scopeLabel,
      incidentReference: _stringValue(json['incident_reference']),
      sourceRouteLabel: sourceRouteLabel,
      approvedAtUtc: approvedAtUtc,
      executionPacket: executionPacket,
    );
  }
}

class OnyxAgentCameraExecutionOutcome {
  final bool success;
  final String providerLabel;
  final String detail;
  final String recommendedNextStep;
  final String remoteExecutionId;
  final DateTime recordedAtUtc;

  const OnyxAgentCameraExecutionOutcome({
    required this.success,
    required this.providerLabel,
    required this.detail,
    required this.recommendedNextStep,
    this.remoteExecutionId = '',
    required this.recordedAtUtc,
  });

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'success': success,
      'provider_label': providerLabel,
      'detail': detail,
      'recommended_next_step': recommendedNextStep,
      'remote_execution_id': remoteExecutionId,
      'recorded_at_utc': recordedAtUtc.toIso8601String(),
    };
  }
}

abstract class OnyxAgentCameraDeviceExecutor {
  bool get isConfigured;

  String get modeLabel;

  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  );
}

typedef OnyxAgentCameraExecutionDelegate =
    Future<OnyxAgentCameraExecutionOutcome> Function(
      OnyxAgentCameraExecutionRequest request,
    );

class LocalOnyxAgentCameraDeviceExecutor
    implements OnyxAgentCameraDeviceExecutor {
  final OnyxAgentCameraExecutionDelegate executeWith;
  @override
  final String modeLabel;

  const LocalOnyxAgentCameraDeviceExecutor({
    required this.executeWith,
    this.modeLabel = 'Embedded camera bridge',
  });

  @override
  bool get isConfigured => false;

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    return executeWith(request);
  }
}

class HttpOnyxAgentCameraDeviceExecutor
    implements OnyxAgentCameraDeviceExecutor {
  final http.Client client;
  final Uri endpoint;
  final String authToken;

  const HttpOnyxAgentCameraDeviceExecutor({
    required this.client,
    required this.endpoint,
    this.authToken = '',
  });

  @override
  bool get isConfigured => true;

  @override
  String get modeLabel => 'LAN ONVIF bridge';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final response = await client.post(
      endpoint,
      headers: <String, String>{
        'content-type': 'application/json',
        if (authToken.trim().isNotEmpty)
          'authorization': 'Bearer ${authToken.trim()}',
      },
      body: jsonEncode(request.toJson()),
    );

    final decoded = _decodeMap(response.body);
    final providerLabel = _firstNonEmpty(
      _stringValue(decoded['provider_label']),
      'lan:http-camera-executor',
    );
    final remoteExecutionId = _firstNonEmpty(
      _stringValue(decoded['execution_id']),
      _stringValue(decoded['remote_execution_id']),
      _stringValue(decoded['audit_id']),
    );
    final recordedAtUtc =
        _dateValue(decoded['executed_at_utc']) ??
        _dateValue(decoded['recorded_at_utc']) ??
        DateTime.now().toUtc();
    final success =
        _boolValue(decoded['success']) ??
        (response.statusCode >= 200 && response.statusCode < 300);
    final detail = _firstNonEmpty(
      _stringValue(decoded['summary']),
      _stringValue(decoded['detail']),
      _stringValue(decoded['message']),
      success
          ? 'The LAN ONVIF bridge accepted the ${request.executionPacket.profileLabel} packet for ${request.executionPacket.vendorLabel}.'
          : 'The LAN ONVIF bridge did not confirm a clean device write.',
    );
    final recommendedNextStep = _firstNonEmpty(
      _stringValue(decoded['next_step']),
      _stringValue(decoded['recommended_next_step']),
      success
          ? 'Validate CCTV live view, substream health, and recorder ingest immediately.'
          : 'Keep the incident open, recheck CCTV manually, and retry only after confirming the target state.',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return OnyxAgentCameraExecutionOutcome(
        success: false,
        providerLabel: providerLabel,
        detail: 'Executor bridge HTTP ${response.statusCode}. $detail',
        recommendedNextStep: recommendedNextStep,
        remoteExecutionId: remoteExecutionId,
        recordedAtUtc: recordedAtUtc,
      );
    }

    return OnyxAgentCameraExecutionOutcome(
      success: success,
      providerLabel: providerLabel,
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: remoteExecutionId,
      recordedAtUtc: recordedAtUtc,
    );
  }
}

abstract class OnyxAgentCameraChangeService {
  bool get isConfigured;

  String get executionModeLabel;

  Future<OnyxAgentCameraChangePlanResult> stage({
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
    required String sourceRouteLabel,
  });

  Future<OnyxAgentCameraExecutionResult> approveAndExecute({
    required String packetId,
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
  });

  Future<OnyxAgentCameraRollbackResult> logRollback({
    required String packetId,
    required String executionId,
    required String target,
  });

  Future<List<OnyxAgentCameraAuditEntry>> readAuditHistory({
    required String clientId,
    required String siteId,
    required String incidentReference,
    int limit = 6,
  });
}

class LocalOnyxAgentCameraChangeService
    implements OnyxAgentCameraChangeService {
  const LocalOnyxAgentCameraChangeService();

  @override
  bool get isConfigured => true;

  @override
  String get executionModeLabel => 'Embedded camera bridge (staging)';

  @override
  Future<OnyxAgentCameraChangePlanResult> stage({
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
    required String sourceRouteLabel,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final packetId = _buildId('CAM-PKT', nowUtc);
    final packet = _buildExecutionPacket(
      packetId: packetId,
      target: target,
      sourceRouteLabel: sourceRouteLabel,
      clientId: clientId,
      siteId: siteId,
    );
    return OnyxAgentCameraChangePlanResult(
      packetId: packetId,
      target: packet.target,
      scopeLabel: _scopeLabel(clientId, siteId),
      incidentReference: incidentReference.trim(),
      sourceRouteLabel: _sourceRouteLabel(sourceRouteLabel),
      createdAtUtc: nowUtc,
      executionPacket: packet,
    );
  }

  @override
  Future<OnyxAgentCameraExecutionResult> approveAndExecute({
    required String packetId,
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final resolvedPacketId = packetId.trim().isEmpty
        ? _buildId('CAM-PKT', nowUtc)
        : packetId.trim();
    final packet = _buildExecutionPacket(
      packetId: resolvedPacketId,
      target: target,
      sourceRouteLabel: 'Agent',
      clientId: clientId,
      siteId: siteId,
    );
    return OnyxAgentCameraExecutionResult(
      packetId: resolvedPacketId,
      executionId: _buildId('CAM-EXEC', nowUtc),
      target: packet.target,
      scopeLabel: _scopeLabel(clientId, siteId),
      incidentReference: incidentReference.trim(),
      approvedAtUtc: nowUtc,
      executionPacket: packet,
    );
  }

  @override
  Future<OnyxAgentCameraRollbackResult> logRollback({
    required String packetId,
    required String executionId,
    required String target,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final resolvedPacketId = packetId.trim().isEmpty
        ? _buildId('CAM-PKT', nowUtc)
        : packetId.trim();
    final packet = _buildExecutionPacket(
      packetId: resolvedPacketId,
      target: target,
      sourceRouteLabel: 'Agent',
      clientId: '',
      siteId: '',
    );
    return OnyxAgentCameraRollbackResult(
      packetId: resolvedPacketId,
      executionId: executionId.trim().isEmpty
          ? _buildId('CAM-EXEC', nowUtc)
          : executionId.trim(),
      rollbackId: _buildId('CAM-RBK', nowUtc),
      target: packet.target,
      recordedAtUtc: nowUtc,
      executionPacket: packet,
    );
  }

  @override
  Future<List<OnyxAgentCameraAuditEntry>> readAuditHistory({
    required String clientId,
    required String siteId,
    required String incidentReference,
    int limit = 6,
  }) async {
    return const <OnyxAgentCameraAuditEntry>[];
  }
}

class PersistedOnyxAgentCameraChangeService
    implements OnyxAgentCameraChangeService {
  final Future<DispatchPersistenceService> persistenceFuture;
  final OnyxAgentCameraDeviceExecutor executor;
  final int maxAuditEntries;

  const PersistedOnyxAgentCameraChangeService({
    required this.persistenceFuture,
    required this.executor,
    this.maxAuditEntries = 24,
  });

  @override
  bool get isConfigured => true;

  @override
  String get executionModeLabel => executor.modeLabel;

  @override
  Future<OnyxAgentCameraChangePlanResult> stage({
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
    required String sourceRouteLabel,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final packetId = _buildId('CAM-PKT', nowUtc);
    final packet = _buildExecutionPacket(
      packetId: packetId,
      target: target,
      sourceRouteLabel: sourceRouteLabel,
      clientId: clientId,
      siteId: siteId,
    );
    final result = OnyxAgentCameraChangePlanResult(
      packetId: packetId,
      target: packet.target,
      scopeLabel: _scopeLabel(clientId, siteId),
      incidentReference: incidentReference.trim(),
      sourceRouteLabel: _sourceRouteLabel(sourceRouteLabel),
      providerLabel: 'local:camera-change-stage',
      createdAtUtc: nowUtc,
      executionPacket: packet,
    );
    await _recordAuditEntry(
      OnyxAgentCameraAuditEntry(
        auditId: result.packetId,
        kind: OnyxAgentCameraAuditKind.staged,
        packetId: result.packetId,
        target: result.target,
        clientId: clientId.trim(),
        siteId: siteId.trim(),
        scopeLabel: result.scopeLabel,
        incidentReference: result.incidentReference,
        sourceRouteLabel: result.sourceRouteLabel,
        providerLabel: result.providerLabel,
        statusLabel: 'approval staged',
        detail:
            'Prepared ${packet.profileLabel} for ${packet.vendorLabel}. Rollback export ${packet.rollbackExportLabel} must be captured before approval.',
        success: true,
        recordedAtUtc: result.createdAtUtc,
        executionPacket: packet,
      ),
    );
    return result;
  }

  @override
  Future<OnyxAgentCameraExecutionResult> approveAndExecute({
    required String packetId,
    required String target,
    required String clientId,
    required String siteId,
    required String incidentReference,
  }) async {
    final history = await _loadAuditHistory();
    final stagedEntry = _findEntryByPacketId(history, packetId);
    final nowUtc = DateTime.now().toUtc();
    final resolvedPacketId = packetId.trim().isEmpty
        ? (stagedEntry?.packetId ?? _buildId('CAM-PKT', nowUtc))
        : packetId.trim();
    final resolvedTarget = _normalizeTarget(
      target.trim().isEmpty ? (stagedEntry?.target ?? '') : target,
    );
    final resolvedClientId = _resolveScopeValue(
      clientId,
      stagedEntry?.clientId,
    );
    final resolvedSiteId = _resolveScopeValue(siteId, stagedEntry?.siteId);
    final resolvedScopeLabel = stagedEntry?.scopeLabel.isNotEmpty == true
        ? stagedEntry!.scopeLabel
        : _scopeLabel(resolvedClientId, resolvedSiteId);
    final resolvedIncidentReference = _resolveScopeValue(
      incidentReference,
      stagedEntry?.incidentReference,
    );
    final resolvedSourceRouteLabel =
        stagedEntry?.sourceRouteLabel.isNotEmpty == true
        ? stagedEntry!.sourceRouteLabel
        : 'Agent';
    final resolvedPacket =
        stagedEntry?.executionPacket ??
        _buildExecutionPacket(
          packetId: resolvedPacketId,
          target: resolvedTarget,
          sourceRouteLabel: resolvedSourceRouteLabel,
          clientId: resolvedClientId,
          siteId: resolvedSiteId,
        );
    final request = OnyxAgentCameraExecutionRequest(
      packetId: resolvedPacketId,
      target: resolvedTarget,
      clientId: resolvedClientId,
      siteId: resolvedSiteId,
      scopeLabel: resolvedScopeLabel,
      incidentReference: resolvedIncidentReference,
      sourceRouteLabel: resolvedSourceRouteLabel,
      approvedAtUtc: nowUtc,
      executionPacket: resolvedPacket,
    );

    OnyxAgentCameraExecutionOutcome outcome;
    try {
      outcome = await executor.execute(request);
    } catch (error) {
      outcome = OnyxAgentCameraExecutionOutcome(
        success: false,
        providerLabel: 'lan:camera-executor-error',
        detail:
            'The execution bridge did not return a confirmed device result: ${error.toString().trim().isEmpty ? error.runtimeType : error.toString().trim()}.',
        recommendedNextStep:
            'Reopen CCTV, confirm the target manually, and retry only after the device state is understood.',
        recordedAtUtc: DateTime.now().toUtc(),
      );
    }

    final result = OnyxAgentCameraExecutionResult(
      packetId: resolvedPacketId,
      executionId: _buildId('CAM-EXEC', outcome.recordedAtUtc),
      remoteExecutionId: outcome.remoteExecutionId,
      target: resolvedTarget,
      scopeLabel: resolvedScopeLabel,
      incidentReference: resolvedIncidentReference,
      providerLabel: outcome.providerLabel,
      approvedAtUtc: outcome.recordedAtUtc,
      success: outcome.success,
      outcomeDetail: outcome.detail,
      recommendedNextStep: outcome.recommendedNextStep,
      executionPacket: resolvedPacket,
    );
    await _recordAuditEntry(
      OnyxAgentCameraAuditEntry(
        auditId: result.executionId,
        kind: OnyxAgentCameraAuditKind.executed,
        packetId: result.packetId,
        executionId: result.executionId,
        target: result.target,
        clientId: resolvedClientId,
        siteId: resolvedSiteId,
        scopeLabel: result.scopeLabel,
        incidentReference: result.incidentReference,
        sourceRouteLabel: resolvedSourceRouteLabel,
        providerLabel: result.providerLabel,
        statusLabel: result.success ? 'executed' : 'follow-up required',
        detail: result.outcomeDetail,
        success: result.success,
        recordedAtUtc: result.approvedAtUtc,
        executionPacket: resolvedPacket,
      ),
    );
    return result;
  }

  @override
  Future<OnyxAgentCameraRollbackResult> logRollback({
    required String packetId,
    required String executionId,
    required String target,
  }) async {
    final history = await _loadAuditHistory();
    final executionEntry = _findExecutionEntry(history, packetId, executionId);
    final nowUtc = DateTime.now().toUtc();
    final resolvedPacketId = packetId.trim().isEmpty
        ? (executionEntry?.packetId ?? _buildId('CAM-PKT', nowUtc))
        : packetId.trim();
    final resolvedPacket =
        executionEntry?.executionPacket ??
        _buildExecutionPacket(
          packetId: resolvedPacketId,
          target: target,
          sourceRouteLabel: executionEntry?.sourceRouteLabel ?? 'Agent',
          clientId: executionEntry?.clientId ?? '',
          siteId: executionEntry?.siteId ?? '',
        );
    final result = OnyxAgentCameraRollbackResult(
      packetId: resolvedPacketId,
      executionId: executionId.trim().isEmpty
          ? (executionEntry?.executionId.isNotEmpty == true
                ? executionEntry!.executionId
                : _buildId('CAM-EXEC', nowUtc))
          : executionId.trim(),
      rollbackId: _buildId('CAM-RBK', nowUtc),
      target: _normalizeTarget(
        target.trim().isEmpty ? resolvedPacket.target : target,
      ),
      scopeLabel: executionEntry?.scopeLabel.isNotEmpty == true
          ? executionEntry!.scopeLabel
          : 'Global controller scope',
      incidentReference: executionEntry?.incidentReference ?? '',
      recordedAtUtc: nowUtc,
      executionPacket: resolvedPacket,
    );
    await _recordAuditEntry(
      OnyxAgentCameraAuditEntry(
        auditId: result.rollbackId,
        kind: OnyxAgentCameraAuditKind.rolledBack,
        packetId: result.packetId,
        executionId: result.executionId,
        rollbackId: result.rollbackId,
        target: result.target,
        clientId: executionEntry?.clientId ?? '',
        siteId: executionEntry?.siteId ?? '',
        scopeLabel: result.scopeLabel,
        incidentReference: result.incidentReference,
        sourceRouteLabel: executionEntry?.sourceRouteLabel ?? 'Agent',
        providerLabel: result.providerLabel,
        statusLabel: 'rollback logged',
        detail:
            'Rollback recorded for ${resolvedPacket.profileLabel}. Restore export ${resolvedPacket.rollbackExportLabel} and recheck recorder target ${resolvedPacket.recorderTarget}.',
        success: true,
        recordedAtUtc: result.recordedAtUtc,
        executionPacket: resolvedPacket,
      ),
    );
    return result;
  }

  @override
  Future<List<OnyxAgentCameraAuditEntry>> readAuditHistory({
    required String clientId,
    required String siteId,
    required String incidentReference,
    int limit = 6,
  }) async {
    final history = await _loadAuditHistory();
    final filtered = history
        .where(
          (entry) => _matchesScope(
            entry: entry,
            clientId: clientId,
            siteId: siteId,
            incidentReference: incidentReference,
          ),
        )
        .toList(growable: false);
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.sublist(0, limit);
  }

  Future<List<OnyxAgentCameraAuditEntry>> _loadAuditHistory() async {
    final persistence = await persistenceFuture;
    final raw = await persistence.readOnyxAgentCameraAuditHistory();
    final entries = raw
        .map(OnyxAgentCameraAuditEntry.fromJson)
        .whereType<OnyxAgentCameraAuditEntry>()
        .toList(growable: true);
    entries.sort((a, b) => b.recordedAtUtc.compareTo(a.recordedAtUtc));
    return entries;
  }

  Future<void> _recordAuditEntry(OnyxAgentCameraAuditEntry entry) async {
    final persistence = await persistenceFuture;
    final history = await _loadAuditHistory();
    final updated = <OnyxAgentCameraAuditEntry>[
      entry,
      ...history.where(
        (existing) =>
            existing.auditId != entry.auditId || existing.kind != entry.kind,
      ),
    ];
    if (updated.length > maxAuditEntries) {
      updated.removeRange(maxAuditEntries, updated.length);
    }
    await persistence.saveOnyxAgentCameraAuditHistory(
      updated.map((item) => item.toJson()).toList(growable: false),
    );
  }
}

class _CameraVendorProfile {
  final String key;
  final String label;
  final String onvifNamespace;
  final String credentialHint;

  const _CameraVendorProfile({
    required this.key,
    required this.label,
    required this.onvifNamespace,
    required this.credentialHint,
  });
}

class _CameraPresetProfile {
  final String key;
  final String label;
  final String mainStreamLabel;
  final String subStreamLabel;
  final String recorderTarget;
  final List<String> verificationPlan;

  const _CameraPresetProfile({
    required this.key,
    required this.label,
    required this.mainStreamLabel,
    required this.subStreamLabel,
    required this.recorderTarget,
    required this.verificationPlan,
  });
}

const List<_CameraVendorProfile> _cameraVendorProfiles = <_CameraVendorProfile>[
  _CameraVendorProfile(
    key: 'generic_onvif',
    label: 'Generic ONVIF',
    onvifNamespace: 'std',
    credentialHint:
        'Keep device credentials local. Redact usernames and passwords from any cloud escalation.',
  ),
  _CameraVendorProfile(
    key: 'hikvision',
    label: 'Hikvision',
    onvifNamespace: 'hik',
    credentialHint:
        'Prefer digest auth and preserve the existing Hikvision user role before any write.',
  ),
  _CameraVendorProfile(
    key: 'dahua',
    label: 'Dahua',
    onvifNamespace: 'dahua',
    credentialHint:
        'Keep Dahua profile bindings and recorder channel mapping intact during encoder changes.',
  ),
  _CameraVendorProfile(
    key: 'axis',
    label: 'Axis',
    onvifNamespace: 'axis',
    credentialHint:
        'Export Axis stream profiles before changes so named stream groups can be restored fast.',
  ),
  _CameraVendorProfile(
    key: 'uniview',
    label: 'Uniview',
    onvifNamespace: 'unv',
    credentialHint:
        'Preserve Uniview codec and smart-stream flags when applying ONVIF updates.',
  ),
];

const List<_CameraPresetProfile> _cameraPresetProfiles = <_CameraPresetProfile>[
  _CameraPresetProfile(
    key: 'balanced_monitoring',
    label: 'Balanced Monitoring',
    mainStreamLabel: 'H.265 1920x1080 @ 15 fps / 2048 kbps',
    subStreamLabel: 'H.264 640x360 @ 8 fps / 384 kbps',
    recorderTarget: 'primary_nvr',
    verificationPlan: <String>[
      'Confirm main stream renders in CCTV without frame starvation.',
      'Confirm substream still opens quickly in mobile and grid views.',
      'Confirm recorder ingest on the primary NVR channel within one minute.',
    ],
  ),
  _CameraPresetProfile(
    key: 'alarm_verification',
    label: 'Alarm Verification',
    mainStreamLabel: 'H.265 2560x1440 @ 18 fps / 3072 kbps',
    subStreamLabel: 'H.264 704x480 @ 10 fps / 512 kbps',
    recorderTarget: 'alarm_review_nvr',
    verificationPlan: <String>[
      'Confirm alarm review grid and full-screen playback both open cleanly.',
      'Confirm motion and analytics overlays remain available after the change.',
      'Confirm the alarm review recorder receives the updated stream.',
    ],
  ),
  _CameraPresetProfile(
    key: 'track_intercept',
    label: 'Track Intercept',
    mainStreamLabel: 'H.265 1920x1080 @ 20 fps / 2560 kbps',
    subStreamLabel: 'H.264 854x480 @ 12 fps / 640 kbps',
    recorderTarget: 'track_ops_nvr',
    verificationPlan: <String>[
      'Confirm operator pan / zoom responsiveness in the tracking view.',
      'Confirm substream remains stable during map and officer tracking pivots.',
      'Confirm the track ops recorder channel stays attached to the stream.',
    ],
  ),
];

OnyxAgentCameraExecutionPacket _buildExecutionPacket({
  required String packetId,
  required String target,
  required String sourceRouteLabel,
  required String clientId,
  required String siteId,
}) {
  final normalizedTarget = _normalizeTarget(target);
  final vendor = _inferVendorProfile(normalizedTarget);
  final preset = _presetForRoute(sourceRouteLabel);
  final rollbackExportLabel = _buildRollbackExportLabel(
    packetId: packetId,
    target: normalizedTarget,
  );
  final scopeLabel = _scopeLabel(clientId, siteId);
  final tokenSuffix = preset.key.replaceAll('_', '-');
  return OnyxAgentCameraExecutionPacket(
    packetId: packetId,
    target: normalizedTarget,
    vendorKey: vendor.key,
    vendorLabel: vendor.label,
    profileKey: preset.key,
    profileLabel: preset.label,
    onvifProfileToken: 'onyx-${vendor.onvifNamespace}-$tokenSuffix',
    mainStreamLabel: preset.mainStreamLabel,
    subStreamLabel: preset.subStreamLabel,
    recorderTarget: preset.recorderTarget,
    rollbackExportLabel: rollbackExportLabel,
    credentialHandling: vendor.credentialHint,
    changePlan: <String>[
      'Read ONVIF media capabilities for $normalizedTarget and confirm the current encoder profile.',
      'Export the pre-change encoder state to $rollbackExportLabel for scope $scopeLabel.',
      'Apply ${preset.label} to the main and substream profiles without changing credentials.',
      'Rebind recorder target ${preset.recorderTarget} only if the current channel mapping drifts.',
    ],
    verificationPlan: preset.verificationPlan,
    rollbackPlan: <String>[
      'Restore the previous stream/profile from $rollbackExportLabel.',
      'Reapply the previous recorder mapping if ingest moved during execution.',
      'Validate live view, substream, and recorder playback before closing the rollback.',
    ],
  );
}

_CameraVendorProfile _inferVendorProfile(String target) {
  final lower = target.toLowerCase();
  if (lower.contains('hik') || lower.contains('ds-')) {
    return _cameraVendorProfiles[1];
  }
  if (lower.contains('dahua') || lower.contains('dh-')) {
    return _cameraVendorProfiles[2];
  }
  if (lower.contains('axis')) {
    return _cameraVendorProfiles[3];
  }
  if (lower.contains('uniview') || lower.contains('unv')) {
    return _cameraVendorProfiles[4];
  }
  return _cameraVendorProfiles.first;
}

_CameraPresetProfile _presetForRoute(String sourceRouteLabel) {
  final lower = sourceRouteLabel.trim().toLowerCase();
  if (lower.contains('track') || lower.contains('tactical')) {
    return _cameraPresetProfiles[2];
  }
  if (lower.contains('alarm') ||
      lower.contains('dispatch') ||
      lower.contains('command')) {
    return _cameraPresetProfiles[1];
  }
  return _cameraPresetProfiles.first;
}

String _buildRollbackExportLabel({
  required String packetId,
  required String target,
}) {
  final normalizedTarget = target
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final targetLabel = normalizedTarget.isEmpty
      ? 'scoped-camera'
      : normalizedTarget;
  return 'rollback-$packetId-$targetLabel.json';
}

String _buildId(String prefix, DateTime timestamp) {
  return '$prefix-${timestamp.microsecondsSinceEpoch}';
}

String _normalizeTarget(String raw) {
  final normalized = raw.trim();
  return normalized.isEmpty ? 'current scoped camera target' : normalized;
}

String _scopeLabel(String clientId, String siteId) {
  final normalizedClientId = clientId.trim();
  final normalizedSiteId = siteId.trim();
  if (normalizedClientId.isEmpty && normalizedSiteId.isEmpty) {
    return 'Global controller scope';
  }
  if (normalizedClientId.isEmpty) {
    return normalizedSiteId;
  }
  if (normalizedSiteId.isEmpty) {
    return '$normalizedClientId • all sites';
  }
  return '$normalizedClientId • $normalizedSiteId';
}

String _sourceRouteLabel(String raw) {
  final normalized = raw.trim();
  return normalized.isEmpty ? 'Command' : normalized;
}

String _resolveScopeValue(String preferred, String? fallback) {
  final normalizedPreferred = preferred.trim();
  if (normalizedPreferred.isNotEmpty) {
    return normalizedPreferred;
  }
  return fallback?.trim() ?? '';
}

bool _matchesScope({
  required OnyxAgentCameraAuditEntry entry,
  required String clientId,
  required String siteId,
  required String incidentReference,
}) {
  final normalizedClientId = clientId.trim();
  final normalizedSiteId = siteId.trim();
  final normalizedIncidentReference = incidentReference.trim();
  if (normalizedClientId.isNotEmpty &&
      entry.clientId.trim() != normalizedClientId) {
    return false;
  }
  if (normalizedSiteId.isNotEmpty && entry.siteId.trim() != normalizedSiteId) {
    return false;
  }
  if (normalizedIncidentReference.isNotEmpty &&
      entry.incidentReference.trim().isNotEmpty &&
      entry.incidentReference.trim() != normalizedIncidentReference) {
    return false;
  }
  return true;
}

OnyxAgentCameraAuditEntry? _findEntryByPacketId(
  List<OnyxAgentCameraAuditEntry> history,
  String packetId,
) {
  final normalizedPacketId = packetId.trim();
  if (normalizedPacketId.isEmpty) {
    return null;
  }
  for (final entry in history) {
    if (entry.packetId == normalizedPacketId) {
      return entry;
    }
  }
  return null;
}

OnyxAgentCameraAuditEntry? _findExecutionEntry(
  List<OnyxAgentCameraAuditEntry> history,
  String packetId,
  String executionId,
) {
  final normalizedExecutionId = executionId.trim();
  final normalizedPacketId = packetId.trim();
  for (final entry in history) {
    if (normalizedExecutionId.isNotEmpty &&
        entry.executionId == normalizedExecutionId) {
      return entry;
    }
    if (normalizedPacketId.isNotEmpty &&
        entry.packetId == normalizedPacketId &&
        entry.executionId.isNotEmpty) {
      return entry;
    }
  }
  return null;
}

Map<String, Object?> _decodeMap(String rawBody) {
  final trimmed = rawBody.trim();
  if (trimmed.isEmpty) {
    return const <String, Object?>{};
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      return const <String, Object?>{};
    }
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  } catch (_) {
    return const <String, Object?>{};
  }
}

String _firstNonEmpty(
  String first, [
  String second = '',
  String third = '',
  String fourth = '',
]) {
  for (final candidate in <String>[first, second, third, fourth]) {
    final normalized = candidate.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((entry) => entry?.toString().trim() ?? '')
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

String _stringValue(Object? value) {
  return value?.toString().trim() ?? '';
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return null;
}

DateTime? _dateValue(Object? value) {
  final raw = _stringValue(value);
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

OnyxAgentCameraAuditKind _auditKindValue(Object? value) {
  final raw = _stringValue(value);
  switch (raw) {
    case 'executed':
      return OnyxAgentCameraAuditKind.executed;
    case 'rolledBack':
      return OnyxAgentCameraAuditKind.rolledBack;
    case 'staged':
    default:
      return OnyxAgentCameraAuditKind.staged;
  }
}
