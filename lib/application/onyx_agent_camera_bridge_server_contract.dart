enum OnyxAgentCameraBridgeStatusDetailVariant { agent, admin }

enum OnyxAgentCameraBridgeAccessVariant { clipboard, agent, admin }

class OnyxAgentCameraBridgeStatusDetail {
  final String label;
  final String value;

  const OnyxAgentCameraBridgeStatusDetail({
    required this.label,
    required this.value,
  });
}

class OnyxAgentCameraBridgeStatus {
  final bool enabled;
  final bool running;
  final bool authRequired;
  final Uri? endpoint;
  final String statusLabel;
  final String detail;

  const OnyxAgentCameraBridgeStatus({
    this.enabled = false,
    this.running = false,
    this.authRequired = false,
    this.endpoint,
    this.statusLabel = 'Disabled',
    this.detail = 'Local camera bridge listener is disabled.',
  });

  bool get isLive => enabled && running;

  String get endpointLabel => endpoint?.toString() ?? 'Not bound';

  String get routeLabel => 'POST /execute • GET /health';

  String get endpointRouteLabel => endpoint == null
      ? routeLabel
      : 'POST ${endpoint!.toString()}/execute • GET ${endpoint!.toString()}/health';

  String describeAccess({
    OnyxAgentCameraBridgeAccessVariant variant =
        OnyxAgentCameraBridgeAccessVariant.clipboard,
  }) {
    if (authRequired) {
      return switch (variant) {
        OnyxAgentCameraBridgeAccessVariant.clipboard => 'Bearer token required',
        OnyxAgentCameraBridgeAccessVariant.agent =>
          'Bearer token required for remote posts',
        OnyxAgentCameraBridgeAccessVariant.admin =>
          'Bearer token required for remote packet posts',
      };
    }
    return switch (variant) {
      OnyxAgentCameraBridgeAccessVariant.clipboard => 'Local access open',
      OnyxAgentCameraBridgeAccessVariant.agent => 'Open on the local ONYX host',
      OnyxAgentCameraBridgeAccessVariant.admin =>
        'Open on the local ONYX host only',
    };
  }

  List<OnyxAgentCameraBridgeStatusDetail> visibleDetailFields({
    OnyxAgentCameraBridgeStatusDetailVariant variant =
        OnyxAgentCameraBridgeStatusDetailVariant.agent,
  }) {
    final accessVariant = switch (variant) {
      OnyxAgentCameraBridgeStatusDetailVariant.agent =>
        OnyxAgentCameraBridgeAccessVariant.agent,
      OnyxAgentCameraBridgeStatusDetailVariant.admin =>
        OnyxAgentCameraBridgeAccessVariant.admin,
    };
    return <OnyxAgentCameraBridgeStatusDetail>[
      OnyxAgentCameraBridgeStatusDetail(
        label: switch (variant) {
          OnyxAgentCameraBridgeStatusDetailVariant.agent => 'Bind',
          OnyxAgentCameraBridgeStatusDetailVariant.admin => 'Bind address',
        },
        value: endpointLabel,
      ),
      OnyxAgentCameraBridgeStatusDetail(label: 'Routes', value: routeLabel),
      OnyxAgentCameraBridgeStatusDetail(
        label: 'Access',
        value: describeAccess(variant: accessVariant),
      ),
    ];
  }

  String toClipboardPayload() {
    return 'ONYX CAMERA BRIDGE\n'
        'Status: ${statusLabel.toUpperCase()}\n'
        'Bind: $endpointLabel\n'
        'Routes: $endpointRouteLabel\n'
        'Auth: ${describeAccess()}\n'
        'Detail: $detail';
  }
}

abstract class OnyxAgentCameraBridgeServer {
  bool get isRunning;

  Uri? get endpoint;

  Future<void> start();

  Future<void> close();
}
