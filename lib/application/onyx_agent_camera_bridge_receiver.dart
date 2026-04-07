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
    // TODO(zaks): Implement Dahua vendor API writes once the ONYX camera worker
    // contract carries the exact encoder/channel payload expected by Dahua.
    return stagingOutcome(
      request,
      detail: stagingMode
          ? 'Camera control in staging mode. Dahua credentials are not configured for ${request.scopeLabel}.'
          : '$workerLabel is credential-ready, but Dahua vendor API writes are still staged in this release.',
      recommendedNextStep:
          'Validate the feed manually, keep ${packet.rollbackExportLabel} attached, and use the Dahua console until the vendor worker is implemented.',
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
    // TODO(zaks): Implement Axis vendor API writes once the ONYX camera worker
    // contract includes the exact stream-group payload needed for Axis devices.
    return stagingOutcome(
      request,
      detail: stagingMode
          ? 'Camera control in staging mode. Axis credentials are not configured for ${request.scopeLabel}.'
          : '$workerLabel is credential-ready, but Axis vendor API writes are still staged in this release.',
      recommendedNextStep:
          'Validate the feed manually, keep ${packet.rollbackExportLabel} attached, and use the Axis console until the vendor worker is implemented.',
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
    // TODO(zaks): Implement Uniview vendor API writes once the ONYX camera
    // worker contract includes the exact encoder payload Uniview accepts.
    return stagingOutcome(
      request,
      detail: stagingMode
          ? 'Camera control in staging mode. Uniview credentials are not configured for ${request.scopeLabel}.'
          : '$workerLabel is credential-ready, but Uniview vendor API writes are still staged in this release.',
      recommendedNextStep:
          'Validate the feed manually, keep ${packet.rollbackExportLabel} attached, and use the Uniview console until the vendor worker is implemented.',
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
