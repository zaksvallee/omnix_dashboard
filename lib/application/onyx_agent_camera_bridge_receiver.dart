import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'dvr_http_auth.dart';
import 'onyx_agent_camera_change_service.dart';

typedef OnyxAgentCameraCredentialsResolver =
    DvrHttpAuthConfig Function(String clientId, String siteId);

abstract class OnyxAgentCameraVendorWorker {
  const OnyxAgentCameraVendorWorker();

  String get vendorKey;

  String get workerLabel;

  bool supports(OnyxAgentCameraExecutionPacket packet) {
    return packet.vendorKey == vendorKey;
  }

  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  );
}

class OnyxAgentCameraBridgeReceiver {
  final List<OnyxAgentCameraVendorWorker> workers;
  final OnyxAgentCameraCredentialsResolver? resolveCredentials;
  final http.Client? httpClient;

  const OnyxAgentCameraBridgeReceiver({
    this.workers = const <OnyxAgentCameraVendorWorker>[
      HikvisionOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      ),
      DahuaOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      ),
      AxisOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      ),
      UniviewOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      ),
      GenericOnyxAgentCameraWorker(
        credentials: DvrHttpAuthConfig(mode: DvrHttpAuthMode.none),
      ),
    ],
    this.resolveCredentials,
    this.httpClient,
  });

  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final worker = _selectWorker(request);
    return worker.execute(request);
  }

  Future<Map<String, Object?>> handleExecutionJson(
    Map<String, Object?> requestJson,
  ) async {
    final request = OnyxAgentCameraExecutionRequest.fromJson(requestJson);
    if (request == null) {
      final nowUtc = DateTime.now().toUtc();
      return <String, Object?>{
        'success': false,
        'provider_label': 'local:camera-bridge-receiver',
        'detail':
            'The execution packet was invalid. packet_id, target, source route, approved_at_utc, and execution_packet are required.',
        'recommended_next_step':
            'Re-stage the camera change packet and retry the approval flow.',
        'recorded_at_utc': nowUtc.toIso8601String(),
      };
    }
    final worker = _selectWorker(request);
    final outcome = await worker.execute(request);
    return <String, Object?>{
      ...outcome.toJson(),
      'worker_label': worker.workerLabel,
      'worker_vendor_key': worker.vendorKey,
      'execution_packet': request.executionPacket.toJson(),
    };
  }

  OnyxAgentCameraVendorWorker _selectWorker(
    OnyxAgentCameraExecutionRequest request,
  ) {
    final packet = request.executionPacket;
    final candidateWorkers = workers.isNotEmpty
        ? workers
        : _defaultWorkersForScope(
            clientId: request.clientId,
            siteId: request.siteId,
          );
    for (final worker in candidateWorkers) {
      if (worker.supports(packet)) {
        return worker;
      }
    }
    return candidateWorkers.firstWhere(
      (worker) => worker.vendorKey == 'generic_onvif',
      orElse: () => GenericOnyxAgentCameraWorker(
        credentials: _credentialsForScope(
          request.clientId,
          request.siteId,
        ),
      ),
    );
  }

  List<OnyxAgentCameraVendorWorker> _defaultWorkersForScope({
    required String clientId,
    required String siteId,
  }) {
    final credentials = _credentialsForScope(clientId, siteId);
    return <OnyxAgentCameraVendorWorker>[
      HikvisionOnyxAgentCameraWorker(
        credentials: credentials,
        httpClient: httpClient,
      ),
      DahuaOnyxAgentCameraWorker(
        credentials: credentials,
        httpClient: httpClient,
      ),
      AxisOnyxAgentCameraWorker(
        credentials: credentials,
        httpClient: httpClient,
      ),
      UniviewOnyxAgentCameraWorker(
        credentials: credentials,
        httpClient: httpClient,
      ),
      GenericOnyxAgentCameraWorker(
        credentials: credentials,
        httpClient: httpClient,
      ),
    ];
  }

  DvrHttpAuthConfig _credentialsForScope(String clientId, String siteId) {
    return resolveCredentials?.call(clientId, siteId) ??
        const DvrHttpAuthConfig(mode: DvrHttpAuthMode.none);
  }
}

abstract class _CredentialReadyOnyxAgentCameraWorker
    extends OnyxAgentCameraVendorWorker {
  final DvrHttpAuthConfig credentials;
  final http.Client? httpClient;

  const _CredentialReadyOnyxAgentCameraWorker({
    required this.credentials,
    this.httpClient,
  });

  bool get stagingMode => !credentials.configured;

  OnyxAgentCameraExecutionOutcome stagingOutcome(
    OnyxAgentCameraExecutionRequest request, {
    required String detail,
    required String recommendedNextStep,
  }) {
    return OnyxAgentCameraExecutionOutcome(
      success: false,
      providerLabel: 'local:camera-worker:$vendorKey',
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: 'worker-$vendorKey-staging-${request.packetId}',
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }
}

class GenericOnyxAgentCameraWorker extends _CredentialReadyOnyxAgentCameraWorker {
  const GenericOnyxAgentCameraWorker({
    required super.credentials,
    super.httpClient,
  });

  @override
  String get vendorKey => 'generic_onvif';

  @override
  String get workerLabel => 'Generic Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final packet = request.executionPacket;
    final detail = stagingMode
        ? 'Camera control in staging mode. ${packet.profileLabel} remains queued because ${packet.vendorLabel} credentials are not configured for ${request.scopeLabel}.'
        : '$workerLabel accepted ${packet.profileLabel}, but generic vendor writes are still staged until the ONVIF API implementation is completed.';
    return stagingOutcome(
      request,
      detail: detail,
      recommendedNextStep:
          'Validate the feed manually, keep ${packet.rollbackExportLabel} attached, and hold the packet open until a vendor-specific worker is live.',
    );
  }
}

class HikvisionOnyxAgentCameraWorker
    extends _CredentialReadyOnyxAgentCameraWorker {
  const HikvisionOnyxAgentCameraWorker({
    required super.credentials,
    super.httpClient,
  });

  @override
  String get vendorKey => 'hikvision';

  @override
  String get workerLabel => 'Hikvision Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final packet = request.executionPacket;
    if (stagingMode) {
      return stagingOutcome(
        request,
        detail:
            'Camera control in staging mode. Configure Hikvision digest or bearer credentials for ${request.scopeLabel} before approving live camera changes.',
        recommendedNextStep:
            'Add the site camera credentials, then retry the approved packet after verifying the target device path.',
      );
    }
    final client = httpClient;
    if (client == null) {
      return _failure(
        request,
        detail:
            'The Hikvision HTTP client is not wired for this runtime.',
        recommendedNextStep:
            'Restore the embedded camera bridge runtime before attempting a live Hikvision write.',
      );
    }

    final targetBaseUri = _deviceBaseUri(request.target);
    if (targetBaseUri == null) {
      return _failure(
        request,
        detail:
            'The target "${request.target}" is not a valid Hikvision host or URL.',
        recommendedNextStep:
            'Restage the packet with a valid camera host or full device URL before retrying the live change.',
      );
    }

    try {
      final deviceInfoUri = targetBaseUri.replace(path: '/ISAPI/System/deviceInfo');
      final deviceInfoResponse = await credentials.get(
        client,
        deviceInfoUri,
        headers: _xmlHeaders,
      );
      if (!_isSuccess(deviceInfoResponse.statusCode) ||
          deviceInfoResponse.body.trim().isEmpty) {
        return _httpFailure(
          request,
          response: deviceInfoResponse,
          detail:
              'Hikvision device verification failed at /ISAPI/System/deviceInfo.',
        );
      }

      final channelsUri = targetBaseUri.replace(path: '/ISAPI/Streaming/channels');
      final channelsResponse = await credentials.get(
        client,
        channelsUri,
        headers: _xmlHeaders,
      );
      if (!_isSuccess(channelsResponse.statusCode)) {
        return _httpFailure(
          request,
          response: channelsResponse,
          detail:
              'Hikvision channel discovery failed at /ISAPI/Streaming/channels.',
        );
      }

      final channelId = _firstChannelId(channelsResponse.body);
      if (channelId == null) {
        return _failure(
          request,
          detail:
              'Hikvision returned no writable streaming channels for ${request.target}.',
          recommendedNextStep:
              'Confirm the device exposes /ISAPI/Streaming/channels and restage the change against the correct host.',
        );
      }

      final listedChannelXml = _channelXmlForId(
        channelsResponse.body,
        channelId,
      );
      if (listedChannelXml == null) {
        return _failure(
          request,
          detail:
              'Hikvision channel $channelId was listed, but the bridge could not build an editable XML payload from the channel listing.',
          recommendedNextStep:
              'Inspect the device channel payload manually and extend the worker before retrying the live write.',
        );
      }

      final desiredPreset = _desiredHikvisionPreset(packet.mainStreamLabel);
      final updatedXml = _applyPresetToChannelXml(
        listedChannelXml,
        desiredPreset,
      );
      if (updatedXml == null) {
        return _failure(
          request,
          detail:
              'Hikvision channel $channelId did not expose common bitrate, frame-rate, or resolution fields that ONYX can safely update yet.',
          recommendedNextStep:
              'Capture the current channel XML, extend the worker mapping, and retry once the target payload shape is supported.',
        );
      }

      final channelUri = targetBaseUri.replace(
        path: '/ISAPI/Streaming/channels/$channelId',
      );
      final putResponse = await http.Response.fromStream(
        await credentials.send(
          client,
          'PUT',
          channelUri,
          headers: const <String, String>{
            'Accept': 'application/xml, text/xml',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          body: updatedXml.xml,
        ),
      );
      if (!_isSuccess(putResponse.statusCode)) {
        return _httpFailure(
          request,
          response: putResponse,
          detail:
              'Hikvision rejected the channel update for channel $channelId.',
        );
      }

      final verifyResponse = await credentials.get(
        client,
        channelUri,
        headers: _xmlHeaders,
      );
      if (!_isSuccess(verifyResponse.statusCode)) {
        return _httpFailure(
          request,
          response: verifyResponse,
          detail:
              'Hikvision did not return a readable confirmation payload for channel $channelId after the update.',
        );
      }
      final mismatches = _verifyPresetValues(
        verifyResponse.body,
        updatedXml.expectedValues,
      );
      if (mismatches.isNotEmpty) {
        return _failure(
          request,
          detail:
              'Hikvision channel $channelId did not confirm ${packet.profileLabel}. Read-back mismatches: ${mismatches.join(', ')}.',
          recommendedNextStep:
              'Keep the incident open, inspect the live device settings, and retry only after confirming which fields the device accepts.',
        );
      }

      return OnyxAgentCameraExecutionOutcome(
        success: true,
        providerLabel: 'local:camera-worker:hikvision',
        detail:
            '$workerLabel confirmed ${packet.profileLabel} on channel $channelId after device verification, channel discovery, live write, and read-back validation.',
        recommendedNextStep:
            'Confirm live view, analytics overlays, and ${packet.recorderTarget} ingest before closing the packet. Keep ${packet.rollbackExportLabel} attached for rollback.',
        remoteExecutionId: 'worker-hikvision-$channelId-${request.packetId}',
        recordedAtUtc: DateTime.now().toUtc(),
      );
    } catch (error) {
      return _failure(
        request,
        detail:
            'Hikvision camera control failed before the change could be confirmed: ${error.toString().trim().isEmpty ? error.runtimeType : error.toString().trim()}.',
        recommendedNextStep:
            'Confirm the target is reachable on the LAN, validate credentials, and retry only after the device path responds cleanly.',
      );
    }
  }

  OnyxAgentCameraExecutionOutcome _httpFailure(
    OnyxAgentCameraExecutionRequest request, {
    required http.Response response,
    required String detail,
  }) {
    final responseDetail = response.body.trim().isEmpty
        ? 'No response body returned.'
        : _collapsed(response.body);
    return _failure(
      request,
      detail: '$detail HTTP ${response.statusCode}. $responseDetail',
      recommendedNextStep:
          'Confirm device credentials and channel permissions, then retry the packet after the Hikvision endpoint responds cleanly.',
    );
  }

  OnyxAgentCameraExecutionOutcome _failure(
    OnyxAgentCameraExecutionRequest request, {
    required String detail,
    required String recommendedNextStep,
  }) {
    return OnyxAgentCameraExecutionOutcome(
      success: false,
      providerLabel: 'local:camera-worker:hikvision',
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: 'worker-hikvision-${request.packetId}',
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }
}

class DahuaOnyxAgentCameraWorker extends _CredentialReadyOnyxAgentCameraWorker {
  const DahuaOnyxAgentCameraWorker({
    required super.credentials,
    super.httpClient,
  });

  @override
  String get vendorKey => 'dahua';

  @override
  String get workerLabel => 'Dahua Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final packet = request.executionPacket;
    if (stagingMode) {
      return stagingOutcome(
        request,
        detail:
            'Camera control in staging mode. Configure Dahua digest credentials for ${request.scopeLabel} before approving live camera changes.',
        recommendedNextStep:
            'Add the site camera credentials, then retry the approved packet after verifying the target device path.',
      );
    }
    final client = httpClient;
    if (client == null) {
      return _dahuaFailure(
        request,
        detail: 'The Dahua HTTP client is not wired for this runtime.',
        recommendedNextStep:
            'Restore the embedded camera bridge runtime before attempting a live Dahua write.',
      );
    }

    final targetBaseUri = _deviceBaseUri(request.target);
    if (targetBaseUri == null) {
      return _dahuaFailure(
        request,
        detail:
            'The target "${request.target}" is not a valid Dahua host or URL.',
        recommendedNextStep:
            'Restage the packet with a valid camera host or full device URL before retrying the live change.',
      );
    }

    try {
      // Step 1 — Verify device is reachable.
      final deviceInfoUri = targetBaseUri.replace(
        path: '/cgi-bin/magicBox.cgi',
        query: 'action=getDeviceType',
      );
      final deviceInfoResponse = await credentials.get(client, deviceInfoUri);
      if (!_isSuccess(deviceInfoResponse.statusCode) ||
          deviceInfoResponse.body.trim().isEmpty) {
        return _dahuaHttpFailure(
          request,
          response: deviceInfoResponse,
          detail: 'Dahua device verification failed at /cgi-bin/magicBox.cgi.',
        );
      }

      // Step 2 — Channel discovery: confirm Encode[0] channel exists.
      final encodeUri = targetBaseUri.replace(
        path: '/cgi-bin/configManager.cgi',
        query: 'action=getConfig&name=Encode%5B0%5D',
      );
      final discoverResponse = await credentials.get(client, encodeUri);
      if (!_isSuccess(discoverResponse.statusCode)) {
        return _dahuaHttpFailure(
          request,
          response: discoverResponse,
          detail:
              'Dahua channel discovery failed at /cgi-bin/configManager.cgi for Encode[0].',
        );
      }
      if (!_dahuaChannelExists(discoverResponse.body)) {
        return _dahuaFailure(
          request,
          detail:
              'Dahua returned no writable Encode[0] channel for ${request.target}.',
          recommendedNextStep:
              'Confirm the device exposes Encode[0] via configManager.cgi and restage the change against the correct host.',
        );
      }

      // Step 3 — Read current config (same endpoint, already have it from step 2).
      final currentConfig = discoverResponse.body;

      // Step 4 — Write preset via CGI param POST.
      final preset = _desiredDahuaPreset(packet.mainStreamLabel);
      final cgiParams = _buildDahuaCgiParams(preset);
      final writeUri = targetBaseUri.replace(
        path: '/cgi-bin/configManager.cgi',
      );
      final postResponse = await http.Response.fromStream(
        await credentials.send(
          client,
          'POST',
          writeUri,
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: cgiParams,
        ),
      );
      if (!_isSuccess(postResponse.statusCode)) {
        return _dahuaHttpFailure(
          request,
          response: postResponse,
          detail:
              'Dahua rejected the Encode[0] configuration update.',
        );
      }

      // Step 5 — Read-back verification.
      final verifyResponse = await credentials.get(client, encodeUri);
      if (!_isSuccess(verifyResponse.statusCode)) {
        return _dahuaHttpFailure(
          request,
          response: verifyResponse,
          detail:
              'Dahua did not return a readable confirmation for Encode[0] after the update.',
        );
      }
      final mismatches = _verifyDahuaConfig(verifyResponse.body, preset);
      if (mismatches.isNotEmpty) {
        return _dahuaFailure(
          request,
          detail:
              'Dahua Encode[0] did not confirm ${packet.profileLabel}. Read-back mismatches: ${mismatches.join(', ')}.',
          recommendedNextStep:
              'Keep the incident open, inspect the live device settings, and retry only after confirming which fields the device accepts.',
        );
      }

      // currentConfig baseline captured — reserved for future diff logging.
      assert(currentConfig.isNotEmpty);
      return OnyxAgentCameraExecutionOutcome(
        success: true,
        providerLabel: 'local:camera-worker:dahua',
        detail:
            '$workerLabel confirmed ${packet.profileLabel} on Encode[0] after device verification, channel discovery, live write, and read-back validation.',
        recommendedNextStep:
            'Confirm live view, analytics overlays, and ${packet.recorderTarget} ingest before closing the packet. Keep ${packet.rollbackExportLabel} attached for rollback.',
        remoteExecutionId: 'worker-dahua-encode0-${request.packetId}',
        recordedAtUtc: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Dahua camera control failed.',
        name: 'OnyxDahuaCameraWorker',
        error: error,
        stackTrace: stackTrace,
      );
      return _dahuaFailure(
        request,
        detail:
            'Dahua camera control failed before the change could be confirmed: ${error.toString().trim().isEmpty ? error.runtimeType : error.toString().trim()}.',
        recommendedNextStep:
            'Confirm the target is reachable on the LAN, validate credentials, and retry only after the device path responds cleanly.',
      );
    }
  }

  OnyxAgentCameraExecutionOutcome _dahuaHttpFailure(
    OnyxAgentCameraExecutionRequest request, {
    required http.Response response,
    required String detail,
  }) {
    final responseDetail = response.body.trim().isEmpty
        ? 'No response body returned.'
        : _collapsed(response.body);
    return _dahuaFailure(
      request,
      detail: '$detail HTTP ${response.statusCode}. $responseDetail',
      recommendedNextStep:
          'Confirm device credentials and channel permissions, then retry the packet after the Dahua endpoint responds cleanly.',
    );
  }

  OnyxAgentCameraExecutionOutcome _dahuaFailure(
    OnyxAgentCameraExecutionRequest request, {
    required String detail,
    required String recommendedNextStep,
  }) {
    return OnyxAgentCameraExecutionOutcome(
      success: false,
      providerLabel: 'local:camera-worker:dahua',
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: 'worker-dahua-${request.packetId}',
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }
}

class AxisOnyxAgentCameraWorker extends _CredentialReadyOnyxAgentCameraWorker {
  const AxisOnyxAgentCameraWorker({
    required super.credentials,
    super.httpClient,
  });

  @override
  String get vendorKey => 'axis';

  @override
  String get workerLabel => 'Axis Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final packet = request.executionPacket;
    if (stagingMode) {
      return stagingOutcome(
        request,
        detail:
            'Camera control in staging mode. Configure Axis digest credentials for ${request.scopeLabel} before approving live camera changes.',
        recommendedNextStep:
            'Add the site camera credentials, then retry the approved packet after verifying the target device path.',
      );
    }
    final client = httpClient;
    if (client == null) {
      return _axisFailure(
        request,
        detail: 'The Axis HTTP client is not wired for this runtime.',
        recommendedNextStep:
            'Restore the embedded camera bridge runtime before attempting a live Axis write.',
      );
    }

    final targetBaseUri = _deviceBaseUri(request.target);
    if (targetBaseUri == null) {
      return _axisFailure(
        request,
        detail:
            'The target "${request.target}" is not a valid Axis host or URL.',
        recommendedNextStep:
            'Restage the packet with a valid camera host or full device URL before retrying the live change.',
      );
    }

    try {
      // Step 1 — Verify device is reachable.
      final deviceInfoUri = targetBaseUri.replace(
        path: '/axis-cgi/basicdeviceinfo.cgi',
      );
      final deviceInfoResponse = await credentials.get(
        client,
        deviceInfoUri,
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      );
      if (!_isSuccess(deviceInfoResponse.statusCode) ||
          deviceInfoResponse.body.trim().isEmpty) {
        return _axisHttpFailure(
          request,
          response: deviceInfoResponse,
          detail:
              'Axis device verification failed at /axis-cgi/basicdeviceinfo.cgi.',
        );
      }

      // Step 2 — Channel discovery: confirm Image.I0 exists.
      final paramUri = targetBaseUri.replace(
        path: '/axis-cgi/param.cgi',
        query: 'action=list&group=Image.I0',
      );
      final discoverResponse = await credentials.get(client, paramUri);
      if (!_isSuccess(discoverResponse.statusCode)) {
        return _axisHttpFailure(
          request,
          response: discoverResponse,
          detail:
              'Axis channel discovery failed at /axis-cgi/param.cgi for Image.I0.',
        );
      }
      if (!_axisChannelExists(discoverResponse.body)) {
        return _axisFailure(
          request,
          detail:
              'Axis returned no writable Image.I0 channel for ${request.target}.',
          recommendedNextStep:
              'Confirm the device exposes Image.I0 via param.cgi and restage the change against the correct host.',
        );
      }

      // Step 3 — Read current config (same endpoint, already have it from step 2).
      final currentConfig = discoverResponse.body;

      // Step 4 — Write preset via form-encoded POST.
      final preset = _desiredAxisPreset(packet.mainStreamLabel);
      final paramBody = _buildAxisParams(preset);
      final writeUri = targetBaseUri.replace(path: '/axis-cgi/param.cgi');
      final postResponse = await http.Response.fromStream(
        await credentials.send(
          client,
          'POST',
          writeUri,
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: paramBody,
        ),
      );
      if (!_isSuccess(postResponse.statusCode)) {
        return _axisHttpFailure(
          request,
          response: postResponse,
          detail: 'Axis rejected the Image.I0 configuration update.',
        );
      }
      if (!_axisWriteAccepted(postResponse.body)) {
        return _axisFailure(
          request,
          detail:
              'Axis did not return OK for the Image.I0 update. Response: ${_collapsed(postResponse.body)}.',
          recommendedNextStep:
              'Inspect the device response, confirm the parameter names are supported on this firmware, and retry.',
        );
      }

      // Step 5 — Read-back verification.
      final verifyResponse = await credentials.get(client, paramUri);
      if (!_isSuccess(verifyResponse.statusCode)) {
        return _axisHttpFailure(
          request,
          response: verifyResponse,
          detail:
              'Axis did not return a readable confirmation for Image.I0 after the update.',
        );
      }
      final mismatches = _verifyAxisConfig(verifyResponse.body, preset);
      if (mismatches.isNotEmpty) {
        return _axisFailure(
          request,
          detail:
              'Axis Image.I0 did not confirm ${packet.profileLabel}. Read-back mismatches: ${mismatches.join(', ')}.',
          recommendedNextStep:
              'Keep the incident open, inspect the live device settings, and retry only after confirming which fields the device accepts.',
        );
      }

      // currentConfig baseline captured — reserved for future diff logging.
      assert(currentConfig.isNotEmpty);
      return OnyxAgentCameraExecutionOutcome(
        success: true,
        providerLabel: 'local:camera-worker:axis',
        detail:
            '$workerLabel confirmed ${packet.profileLabel} on Image.I0 after device verification, channel discovery, live write, and read-back validation.',
        recommendedNextStep:
            'Confirm live view, analytics overlays, and ${packet.recorderTarget} ingest before closing the packet. Keep ${packet.rollbackExportLabel} attached for rollback.',
        remoteExecutionId: 'worker-axis-image0-${request.packetId}',
        recordedAtUtc: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Axis camera control failed.',
        name: 'OnyxAxisCameraWorker',
        error: error,
        stackTrace: stackTrace,
      );
      return _axisFailure(
        request,
        detail:
            'Axis camera control failed before the change could be confirmed: ${error.toString().trim().isEmpty ? error.runtimeType : error.toString().trim()}.',
        recommendedNextStep:
            'Confirm the target is reachable on the LAN, validate credentials, and retry only after the device path responds cleanly.',
      );
    }
  }

  OnyxAgentCameraExecutionOutcome _axisHttpFailure(
    OnyxAgentCameraExecutionRequest request, {
    required http.Response response,
    required String detail,
  }) {
    final responseDetail = response.body.trim().isEmpty
        ? 'No response body returned.'
        : _collapsed(response.body);
    return _axisFailure(
      request,
      detail: '$detail HTTP ${response.statusCode}. $responseDetail',
      recommendedNextStep:
          'Confirm device credentials and channel permissions, then retry the packet after the Axis endpoint responds cleanly.',
    );
  }

  OnyxAgentCameraExecutionOutcome _axisFailure(
    OnyxAgentCameraExecutionRequest request, {
    required String detail,
    required String recommendedNextStep,
  }) {
    return OnyxAgentCameraExecutionOutcome(
      success: false,
      providerLabel: 'local:camera-worker:axis',
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: 'worker-axis-${request.packetId}',
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }
}

class UniviewOnyxAgentCameraWorker extends _CredentialReadyOnyxAgentCameraWorker {
  const UniviewOnyxAgentCameraWorker({
    required super.credentials,
    super.httpClient,
  });

  @override
  String get vendorKey => 'uniview';

  @override
  String get workerLabel => 'Uniview Camera Worker';

  @override
  Future<OnyxAgentCameraExecutionOutcome> execute(
    OnyxAgentCameraExecutionRequest request,
  ) async {
    final packet = request.executionPacket;
    if (stagingMode) {
      return stagingOutcome(
        request,
        detail:
            'Camera control in staging mode. Configure Uniview credentials for ${request.scopeLabel} before approving live camera changes.',
        recommendedNextStep:
            'Add the site camera credentials, then retry the approved packet after verifying the target device path.',
      );
    }
    final client = httpClient;
    if (client == null) {
      return _univiewFailure(
        request,
        detail: 'The Uniview HTTP client is not wired for this runtime.',
        recommendedNextStep:
            'Restore the embedded camera bridge runtime before attempting a live Uniview write.',
      );
    }

    final targetBaseUri = _deviceBaseUri(request.target);
    if (targetBaseUri == null) {
      return _univiewFailure(
        request,
        detail:
            'The target "${request.target}" is not a valid Uniview host or URL.',
        recommendedNextStep:
            'Restage the packet with a valid camera host or full device URL before retrying the live change.',
      );
    }

    try {
      // Step 1 — Verify device is reachable.
      final deviceInfoUri = targetBaseUri.replace(
        path: '/LAPI/V1.0/System/DeviceInfo',
      );
      final deviceInfoResponse = await credentials.get(
        client,
        deviceInfoUri,
        headers: _univiewAuthHeaders(),
      );
      if (!_isSuccess(deviceInfoResponse.statusCode) ||
          deviceInfoResponse.body.trim().isEmpty) {
        return _univiewHttpFailure(
          request,
          response: deviceInfoResponse,
          detail:
              'Uniview device verification failed at /LAPI/V1.0/System/DeviceInfo.',
        );
      }

      // Step 2 — Channel discovery: confirm Mainstream video params exist.
      final streamUri = targetBaseUri.replace(
        path: '/LAPI/V1.0/Channels/0/Media/Video/Mainstream',
      );
      final discoverResponse = await credentials.get(
        client,
        streamUri,
        headers: _univiewAuthHeaders(),
      );
      if (!_isSuccess(discoverResponse.statusCode)) {
        return _univiewHttpFailure(
          request,
          response: discoverResponse,
          detail:
              'Uniview channel discovery failed at /LAPI/V1.0/Channels/0/Media/Video/Mainstream.',
        );
      }
      if (!_univiewChannelExists(discoverResponse.body)) {
        return _univiewFailure(
          request,
          detail:
              'Uniview returned no readable Mainstream channel for ${request.target}.',
          recommendedNextStep:
              'Confirm the device exposes /LAPI/V1.0/Channels/0/Media/Video/Mainstream and restage the change against the correct host.',
        );
      }

      // Step 3 — Read current config (same response from step 2).
      final currentConfig = discoverResponse.body;

      // Step 4 — Write preset via JSON PUT.
      final preset = _desiredUniviewPreset(packet.mainStreamLabel);
      final putBody = _buildUniviewPayload(preset);
      final writeResponse = await http.Response.fromStream(
        await credentials.send(
          client,
          'PUT',
          streamUri,
          headers: _univiewAuthHeaders(),
          body: putBody,
        ),
      );
      if (!_isSuccess(writeResponse.statusCode)) {
        return _univiewHttpFailure(
          request,
          response: writeResponse,
          detail:
              'Uniview rejected the Mainstream configuration update.',
        );
      }
      if (!_univiewWriteAccepted(writeResponse.body)) {
        return _univiewFailure(
          request,
          detail:
              'Uniview did not confirm the Mainstream update. Response: ${_collapsed(writeResponse.body)}.',
          recommendedNextStep:
              'Inspect the device response, confirm the channel index and parameter names are supported on this firmware, and retry.',
        );
      }

      // Step 5 — Read-back verification.
      final verifyResponse = await credentials.get(
        client,
        streamUri,
        headers: _univiewAuthHeaders(),
      );
      if (!_isSuccess(verifyResponse.statusCode)) {
        return _univiewHttpFailure(
          request,
          response: verifyResponse,
          detail:
              'Uniview did not return a readable confirmation for Mainstream after the update.',
        );
      }
      final mismatches = _verifyUniviewConfig(verifyResponse.body, preset);
      if (mismatches.isNotEmpty) {
        return _univiewFailure(
          request,
          detail:
              'Uniview Mainstream did not confirm ${packet.profileLabel}. Read-back mismatches: ${mismatches.join(', ')}.',
          recommendedNextStep:
              'Keep the incident open, inspect the live device settings, and retry only after confirming which fields the device accepts.',
        );
      }

      // currentConfig baseline captured — reserved for future diff logging.
      assert(currentConfig.isNotEmpty);
      return OnyxAgentCameraExecutionOutcome(
        success: true,
        providerLabel: 'local:camera-worker:uniview',
        detail:
            '$workerLabel confirmed ${packet.profileLabel} on Mainstream after device verification, channel discovery, live write, and read-back validation.',
        recommendedNextStep:
            'Confirm live view, analytics overlays, and ${packet.recorderTarget} ingest before closing the packet. Keep ${packet.rollbackExportLabel} attached for rollback.',
        remoteExecutionId: 'worker-uniview-mainstream-${request.packetId}',
        recordedAtUtc: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Uniview camera control failed.',
        name: 'OnyxUniviewCameraWorker',
        error: error,
        stackTrace: stackTrace,
      );
      return _univiewFailure(
        request,
        detail:
            'Uniview camera control failed before the change could be confirmed: ${error.toString().trim().isEmpty ? error.runtimeType : error.toString().trim()}.',
        recommendedNextStep:
            'Confirm the target is reachable on the LAN, validate credentials, and retry only after the device path responds cleanly.',
      );
    }
  }

  OnyxAgentCameraExecutionOutcome _univiewHttpFailure(
    OnyxAgentCameraExecutionRequest request, {
    required http.Response response,
    required String detail,
  }) {
    final responseDetail = response.body.trim().isEmpty
        ? 'No response body returned.'
        : _collapsed(response.body);
    return _univiewFailure(
      request,
      detail: '$detail HTTP ${response.statusCode}. $responseDetail',
      recommendedNextStep:
          'Confirm device credentials and channel permissions, then retry the packet after the Uniview endpoint responds cleanly.',
    );
  }

  OnyxAgentCameraExecutionOutcome _univiewFailure(
    OnyxAgentCameraExecutionRequest request, {
    required String detail,
    required String recommendedNextStep,
  }) {
    return OnyxAgentCameraExecutionOutcome(
      success: false,
      providerLabel: 'local:camera-worker:uniview',
      detail: detail,
      recommendedNextStep: recommendedNextStep,
      remoteExecutionId: 'worker-uniview-${request.packetId}',
      recordedAtUtc: DateTime.now().toUtc(),
    );
  }
}

const Map<String, String> _xmlHeaders = <String, String>{
  'Accept': 'application/xml, text/xml',
};

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

Uri? _deviceBaseUri(String rawTarget) {
  final trimmed = rawTarget.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final direct = Uri.tryParse(trimmed);
  if (direct != null && direct.hasScheme && direct.host.isNotEmpty) {
    return direct.replace(path: '', query: null, fragment: null);
  }
  final hostOnly = Uri.tryParse('http://$trimmed');
  if (hostOnly == null || hostOnly.host.isEmpty) {
    return null;
  }
  return hostOnly.replace(path: '', query: null, fragment: null);
}

String? _firstChannelId(String xml) {
  final match = RegExp(
    r'<StreamingChannel\b[^>]*>[\s\S]*?<id>\s*([^<]+?)\s*</id>[\s\S]*?</StreamingChannel>',
    caseSensitive: false,
  ).firstMatch(xml);
  if (match != null) {
    return match.group(1)?.trim();
  }
  final fallback = RegExp(
    r'<id>\s*([^<]+?)\s*</id>',
    caseSensitive: false,
  ).firstMatch(xml);
  return fallback?.group(1)?.trim();
}

String? _channelXmlForId(String xml, String channelId) {
  final pattern = RegExp(
    '<StreamingChannel\\b[^>]*>[\\s\\S]*?<id>\\s*${RegExp.escape(channelId)}\\s*</id>[\\s\\S]*?</StreamingChannel>',
    caseSensitive: false,
  );
  final exact = pattern.firstMatch(xml)?.group(0)?.trim();
  if (exact != null && exact.isNotEmpty) {
    return exact;
  }
  final firstChannel = RegExp(
    r'<StreamingChannel\b[^>]*>[\s\S]*?</StreamingChannel>',
    caseSensitive: false,
  ).firstMatch(xml);
  return firstChannel?.group(0)?.trim();
}

_HikvisionPreset _desiredHikvisionPreset(String mainStreamLabel) {
  final match = RegExp(
    r'(\d+)x(\d+)\s*@\s*(\d+)\s*fps\s*/\s*(\d+)\s*kbps',
    caseSensitive: false,
  ).firstMatch(mainStreamLabel);
  if (match == null) {
    return const _HikvisionPreset(
      width: '1920',
      height: '1080',
      frameRate: '15',
      bitRate: '2048',
    );
  }
  return _HikvisionPreset(
    width: match.group(1)!.trim(),
    height: match.group(2)!.trim(),
    frameRate: match.group(3)!.trim(),
    bitRate: match.group(4)!.trim(),
  );
}

_UpdatedHikvisionChannelXml? _applyPresetToChannelXml(
  String xml,
  _HikvisionPreset preset,
) {
  var updatedXml = xml;
  final expectedValues = <String, String>{};

  void replaceTag(String tag, String value) {
    final updated = updatedXml.replaceFirstMapped(
      RegExp(
        '(<$tag>)([\\s\\S]*?)(</$tag>)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}$value${match.group(3)}',
    );
    if (updated != updatedXml) {
      updatedXml = updated;
      expectedValues[tag] = value;
    }
  }

  replaceTag('videoResolutionWidth', preset.width);
  replaceTag('videoResolutionHeight', preset.height);
  replaceTag('maxFrameRate', preset.frameRate);
  replaceTag('constantBitRate', preset.bitRate);
  replaceTag('averageVideoBitRate', preset.bitRate);
  replaceTag('vbrUpperCap', preset.bitRate);

  if (expectedValues.isEmpty) {
    return null;
  }
  return _UpdatedHikvisionChannelXml(
    xml: updatedXml,
    expectedValues: expectedValues,
  );
}

List<String> _verifyPresetValues(
  String xml,
  Map<String, String> expectedValues,
) {
  final mismatches = <String>[];
  expectedValues.forEach((tag, expected) {
    final actual = _xmlValue(xml, tag);
    if (actual != expected) {
      mismatches.add('$tag=$actual (expected $expected)');
    }
  });
  return mismatches;
}

String _xmlValue(String xml, String tag) {
  final match = RegExp(
    '<$tag>\\s*([^<]+?)\\s*</$tag>',
    caseSensitive: false,
  ).firstMatch(xml);
  return match?.group(1)?.trim() ?? '';
}

String _collapsed(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ─── Dahua helpers ────────────────────────────────────────────────────────────

bool _dahuaChannelExists(String body) {
  return body.trim().isNotEmpty &&
      body.toLowerCase().contains('encode[0]') &&
      !body.toLowerCase().contains('error');
}

class _DahuaPreset {
  final String width;
  final String height;
  final String fps;
  final String bitrate;

  const _DahuaPreset({
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
  });
}

_DahuaPreset _desiredDahuaPreset(String mainStreamLabel) {
  final match = RegExp(
    r'(\d+)x(\d+)\s*@\s*(\d+)\s*fps\s*/\s*(\d+)\s*kbps',
    caseSensitive: false,
  ).firstMatch(mainStreamLabel);
  if (match == null) {
    return const _DahuaPreset(
      width: '1920',
      height: '1080',
      fps: '15',
      bitrate: '2048',
    );
  }
  return _DahuaPreset(
    width: match.group(1)!.trim(),
    height: match.group(2)!.trim(),
    fps: match.group(3)!.trim(),
    bitrate: match.group(4)!.trim(),
  );
}

/// Builds an `application/x-www-form-urlencoded` body for Dahua configManager
/// setConfig targeting the Encode[0].MainFormat[0].Video fields.
String _buildDahuaCgiParams(_DahuaPreset preset) {
  final params = <String, String>{
    'action': 'setConfig',
    'Encode[0].MainFormat[0].Video.Width': preset.width,
    'Encode[0].MainFormat[0].Video.Height': preset.height,
    'Encode[0].MainFormat[0].Video.FPS': preset.fps,
    'Encode[0].MainFormat[0].Video.BitRate': preset.bitrate,
  };
  return params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');
}

/// Verifies that the Dahua getConfig response contains the expected preset
/// values. Returns a list of mismatch descriptions (empty = all confirmed).
List<String> _verifyDahuaConfig(String body, _DahuaPreset preset) {
  final mismatches = <String>[];
  final fields = <String, String>{
    'Encode[0].MainFormat[0].Video.Width': preset.width,
    'Encode[0].MainFormat[0].Video.Height': preset.height,
    'Encode[0].MainFormat[0].Video.FPS': preset.fps,
    'Encode[0].MainFormat[0].Video.BitRate': preset.bitrate,
  };
  fields.forEach((key, expected) {
    // Dahua response lines look like: table.Encode[0].MainFormat[0].Video.Width=1920
    final escapedKey = RegExp.escape(key);
    final match = RegExp(
      r'(?:^|\n)\s*(?:table\.)?' + escapedKey + r'\s*=\s*([^\r\n]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(body);
    final actual = match?.group(1)?.trim() ?? '';
    if (actual != expected) {
      mismatches.add('$key=$actual (expected $expected)');
    }
  });
  return mismatches;
}

// ─── Axis helpers ─────────────────────────────────────────────────────────────

bool _axisChannelExists(String body) {
  return body.trim().isNotEmpty &&
      body.toLowerCase().contains('image.i0') &&
      !body.toLowerCase().startsWith('error');
}

/// Returns true when the Axis param.cgi POST response signals success.
/// VAPIX returns the plain text string "OK" (case-insensitive) on success.
bool _axisWriteAccepted(String body) {
  return body.trim().toLowerCase() == 'ok';
}

class _AxisPreset {
  final String resolution; // e.g. '1920x1080'
  final String fps;        // e.g. '15'

  const _AxisPreset({required this.resolution, required this.fps});
}

_AxisPreset _desiredAxisPreset(String mainStreamLabel) {
  final match = RegExp(
    r'(\d+)x(\d+)\s*@\s*(\d+)\s*fps',
    caseSensitive: false,
  ).firstMatch(mainStreamLabel);
  if (match == null) {
    return const _AxisPreset(resolution: '1920x1080', fps: '15');
  }
  return _AxisPreset(
    resolution: '${match.group(1)!.trim()}x${match.group(2)!.trim()}',
    fps: match.group(3)!.trim(),
  );
}

/// Builds an `application/x-www-form-urlencoded` body for Axis VAPIX
/// param.cgi update targeting Image.I0.
String _buildAxisParams(_AxisPreset preset) {
  final params = <String, String>{
    'action': 'update',
    'Image.I0.Resolution': preset.resolution,
    'Image.I0.FPS': preset.fps,
  };
  return params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');
}

/// Verifies that the Axis param.cgi list response contains the expected
/// preset values. Returns a list of mismatch descriptions (empty = confirmed).
/// Response lines look like: root.Image.I0.Resolution=1920x1080
List<String> _verifyAxisConfig(String body, _AxisPreset preset) {
  final mismatches = <String>[];
  final fields = <String, String>{
    'Image.I0.Resolution': preset.resolution,
    'Image.I0.FPS': preset.fps,
  };
  fields.forEach((key, expected) {
    final escapedKey = RegExp.escape(key);
    final match = RegExp(
      r'(?:^|\n)\s*(?:root\.)?' + escapedKey + r'\s*=\s*([^\r\n]+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(body);
    final actual = match?.group(1)?.trim() ?? '';
    if (actual != expected) {
      mismatches.add('$key=$actual (expected $expected)');
    }
  });
  return mismatches;
}

// ─── Uniview helpers ──────────────────────────────────────────────────────────

/// Returns the JSON headers required for all Uniview LAPI requests.
/// Auth is handled by [DvrHttpAuthConfig]; these headers declare the payload
/// and acceptance types only.
Map<String, String> _univiewAuthHeaders() {
  return const <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };
}

bool _univiewChannelExists(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return false;
    final response = decoded['Response'] as Map<String, dynamic>?;
    final statusCode = response?['StatusCode'];
    if (statusCode != null && statusCode != 0) return false;
    final params =
        response?['VideoEncodeParam'] ?? decoded['VideoEncodeParam'];
    return params != null;
  } catch (_) {
    return false;
  }
}

/// Returns true when the Uniview LAPI PUT response signals success.
/// LAPI returns a JSON envelope with `StatusCode=0` on success.
bool _univiewWriteAccepted(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return false;
    final response = decoded['Response'] as Map<String, dynamic>?;
    final statusCode = response?['StatusCode'];
    return statusCode == null || statusCode == 0;
  } catch (_) {
    return false;
  }
}

class _UniviewPreset {
  /// Resolution in Uniview wire format, e.g. '2560*1440' (uses `*` separator).
  final String resolution;
  final int fps;
  final int bitrate; // kbps

  const _UniviewPreset({
    required this.resolution,
    required this.fps,
    required this.bitrate,
  });
}

_UniviewPreset _desiredUniviewPreset(String mainStreamLabel) {
  final match = RegExp(
    r'(\d+)x(\d+)\s*@\s*(\d+)\s*fps\s*/\s*(\d+)\s*kbps',
    caseSensitive: false,
  ).firstMatch(mainStreamLabel);
  if (match == null) {
    return const _UniviewPreset(
      resolution: '1920*1080',
      fps: 15,
      bitrate: 2048,
    );
  }
  return _UniviewPreset(
    resolution: '${match.group(1)!.trim()}*${match.group(2)!.trim()}',
    fps: int.tryParse(match.group(3)!.trim()) ?? 15,
    bitrate: int.tryParse(match.group(4)!.trim()) ?? 2048,
  );
}

/// Builds the JSON body for the Uniview LAPI PUT Mainstream request.
String _buildUniviewPayload(_UniviewPreset preset) {
  return jsonEncode(<String, dynamic>{
    'VideoEncodeParam': <String, dynamic>{
      'Resolution': preset.resolution,
      'FrameRate': preset.fps,
      'BitRate': preset.bitrate,
    },
  });
}

/// Verifies that the Uniview LAPI GET Mainstream response contains the
/// expected preset values. Returns a list of mismatch descriptions
/// (empty = all confirmed).
List<String> _verifyUniviewConfig(String body, _UniviewPreset preset) {
  final mismatches = <String>[];
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      mismatches.add('VideoEncodeParam=unreadable (unexpected JSON shape)');
      return mismatches;
    }
    final response = decoded['Response'] as Map<String, dynamic>?;
    final params = (response?['VideoEncodeParam'] ??
        decoded['VideoEncodeParam']) as Map<String, dynamic>?;
    if (params == null) {
      mismatches
          .add('VideoEncodeParam=missing (expected ${preset.resolution})');
      return mismatches;
    }
    final resolution = params['Resolution']?.toString() ?? '';
    if (resolution != preset.resolution) {
      mismatches.add(
        'VideoEncodeParam.Resolution=$resolution (expected ${preset.resolution})',
      );
    }
    final fpsActual = params['FrameRate']?.toString() ?? '';
    if (fpsActual != preset.fps.toString()) {
      mismatches.add(
        'VideoEncodeParam.FrameRate=$fpsActual (expected ${preset.fps})',
      );
    }
  } catch (_) {
    mismatches.add('VideoEncodeParam=unreadable (JSON parse failed)');
  }
  return mismatches;
}

// ─────────────────────────────────────────────────────────────────────────────

class _HikvisionPreset {
  final String width;
  final String height;
  final String frameRate;
  final String bitRate;

  const _HikvisionPreset({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitRate,
  });
}

class _UpdatedHikvisionChannelXml {
  final String xml;
  final Map<String, String> expectedValues;

  const _UpdatedHikvisionChannelXml({
    required this.xml,
    required this.expectedValues,
  });
}
