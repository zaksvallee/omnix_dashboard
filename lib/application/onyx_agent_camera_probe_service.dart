import 'package:http/http.dart' as http;

import 'onyx_agent_tcp_probe_stub.dart'
    if (dart.library.io) 'onyx_agent_tcp_probe_io.dart'
    as tcp_probe;

typedef OnyxAgentPortProbe =
    Future<bool> Function(String host, int port, Duration timeout);
typedef OnyxAgentHttpStatusProbe =
    Future<int?> Function(Uri uri, Duration timeout);

class OnyxAgentCameraProbeResult {
  final String target;
  final Map<int, bool> openPorts;
  final int? rootHttpStatus;
  final int? onvifHttpStatus;

  const OnyxAgentCameraProbeResult({
    required this.target,
    this.openPorts = const <int, bool>{},
    this.rootHttpStatus,
    this.onvifHttpStatus,
  });

  bool get hasAnyReachablePort => openPorts.values.any((value) => value);

  String toOperatorSummary() {
    String portLabel(int port, String label) {
      final open = openPorts[port] ?? false;
      return '$label $port: ${open ? 'open' : 'closed'}';
    }

    final rootStatus = rootHttpStatus == null ? 'n/a' : '$rootHttpStatus';
    final onvifStatus = onvifHttpStatus == null ? 'n/a' : '$onvifHttpStatus';
    final nextStep = hasAnyReachablePort
        ? 'Next step: confirm approved credentials, then validate the stream or ONVIF profile before any write action.'
        : 'Next step: confirm the device is on the LAN, verify power/PoE, and recheck the target IP.';
    return 'Target: $target\n'
        '${portLabel(80, 'HTTP')}\n'
        '${portLabel(443, 'HTTPS')}\n'
        '${portLabel(554, 'RTSP')}\n'
        '${portLabel(8899, 'ONVIF')}\n'
        'HTTP root status: $rootStatus\n'
        'ONVIF endpoint status: $onvifStatus\n'
        '$nextStep';
  }
}

abstract class OnyxAgentCameraProbeService {
  bool get isConfigured;

  Future<OnyxAgentCameraProbeResult> probe(String target);
}

class HttpOnyxAgentCameraProbeService implements OnyxAgentCameraProbeService {
  final http.Client client;
  final OnyxAgentPortProbe portProbe;
  final OnyxAgentHttpStatusProbe httpStatusProbe;
  final Duration tcpTimeout;
  final Duration httpTimeout;

  HttpOnyxAgentCameraProbeService({
    required this.client,
    OnyxAgentPortProbe? portProbe,
    OnyxAgentHttpStatusProbe? httpStatusProbe,
    this.tcpTimeout = const Duration(seconds: 1),
    this.httpTimeout = const Duration(seconds: 2),
  }) : portProbe = portProbe ?? tcp_probe.onyxAgentCanConnect,
       httpStatusProbe = httpStatusProbe ?? _defaultHttpStatusProbe(client);

  @override
  bool get isConfigured => true;

  @override
  Future<OnyxAgentCameraProbeResult> probe(String target) async {
    final normalizedTarget = _normalizeTarget(target);
    final probePorts = const <int>[80, 443, 554, 8899];
    final portChecks = <int, Future<bool>>{
      for (final port in probePorts)
        port: portProbe(normalizedTarget, port, tcpTimeout),
    };
    final portValues = await Future.wait(portChecks.values);
    final ports = <int, bool>{};
    for (int index = 0; index < probePorts.length; index++) {
      ports[probePorts[index]] = portValues[index];
    }

    int? rootStatus;
    if (ports[80] == true) {
      rootStatus = await httpStatusProbe(
        Uri.parse('http://$normalizedTarget/'),
        httpTimeout,
      );
    } else if (ports[443] == true) {
      rootStatus = await httpStatusProbe(
        Uri.parse('https://$normalizedTarget/'),
        httpTimeout,
      );
    }

    int? onvifStatus;
    if (ports[8899] == true) {
      onvifStatus = await httpStatusProbe(
        Uri.parse('http://$normalizedTarget:8899/onvif/device_service'),
        httpTimeout,
      );
    }
    onvifStatus ??= await httpStatusProbe(
      Uri.parse('http://$normalizedTarget/onvif/device_service'),
      httpTimeout,
    );

    return OnyxAgentCameraProbeResult(
      target: normalizedTarget,
      openPorts: ports,
      rootHttpStatus: rootStatus,
      onvifHttpStatus: onvifStatus,
    );
  }
}

String _normalizeTarget(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.host.trim().isNotEmpty) {
    return uri.host.trim();
  }
  final withoutPath = trimmed.split('/').first.trim();
  final withoutPort = withoutPath.contains(':')
      ? withoutPath.split(':').first.trim()
      : withoutPath;
  return withoutPort;
}

OnyxAgentHttpStatusProbe _defaultHttpStatusProbe(http.Client client) {
  return (uri, timeout) async {
    try {
      final response = await client
          .get(uri, headers: const {'Accept': '*/*'})
          .timeout(timeout);
      return response.statusCode;
    } catch (_) {
      return null;
    }
  };
}
