import 'dvr_http_auth.dart';
import 'dvr_scope_config.dart';

class LocalHikvisionDvrProxyRuntimeConfig {
  final Uri eventsUri;
  final String bindHost;
  final int bindPort;
  final Uri upstreamAlertStreamUri;
  final DvrHttpAuthConfig upstreamAuth;

  const LocalHikvisionDvrProxyRuntimeConfig({
    required this.eventsUri,
    required this.bindHost,
    required this.bindPort,
    required this.upstreamAlertStreamUri,
    required this.upstreamAuth,
  });
}

class LocalHikvisionDvrProxyRuntimeConfigResolver {
  const LocalHikvisionDvrProxyRuntimeConfigResolver();

  LocalHikvisionDvrProxyRuntimeConfig? resolve({
    required Iterable<DvrScopeConfig> scopes,
    required Uri? upstreamAlertStreamUri,
    required String upstreamAuthMode,
    String? upstreamUsername,
    String? upstreamPassword,
  }) {
    if (upstreamAlertStreamUri == null) {
      return null;
    }
    Uri? localEventsUri;
    for (final scope in scopes) {
      final candidate = scope.eventsUri;
      if (candidate == null || !_isLoopbackHost(candidate.host)) {
        continue;
      }
      localEventsUri = candidate;
      break;
    }
    if (localEventsUri == null) {
      return null;
    }
    if (_sameEndpoint(localEventsUri, upstreamAlertStreamUri)) {
      return null;
    }
    final bindHost = localEventsUri.host.trim().isEmpty
        ? '127.0.0.1'
        : localEventsUri.host.trim();
    return LocalHikvisionDvrProxyRuntimeConfig(
      eventsUri: localEventsUri,
      bindHost: bindHost,
      bindPort: localEventsUri.hasPort ? localEventsUri.port : 80,
      upstreamAlertStreamUri: upstreamAlertStreamUri,
      upstreamAuth: DvrHttpAuthConfig(
        mode: parseDvrHttpAuthMode(upstreamAuthMode),
        username: (upstreamUsername ?? '').trim().isEmpty
            ? null
            : upstreamUsername!.trim(),
        password: (upstreamPassword ?? '').isEmpty ? null : upstreamPassword,
      ),
    );
  }

  bool _isLoopbackHost(String rawHost) {
    final normalized = rawHost.trim().toLowerCase();
    return normalized == '127.0.0.1' || normalized == 'localhost';
  }

  bool _sameEndpoint(Uri a, Uri b) {
    final aHost = a.host.trim().toLowerCase();
    final bHost = b.host.trim().toLowerCase();
    final aPort = a.hasPort ? a.port : (a.scheme == 'https' ? 443 : 80);
    final bPort = b.hasPort ? b.port : (b.scheme == 'https' ? 443 : 80);
    return a.scheme == b.scheme &&
        aHost == bHost &&
        aPort == bPort &&
        a.path == b.path;
  }
}
