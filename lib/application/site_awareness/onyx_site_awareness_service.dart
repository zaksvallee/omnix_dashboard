import 'onyx_site_awareness_snapshot.dart';

abstract class OnyxSiteAwarenessService {
  /// Start consuming the event stream for a site.
  Future<void> start({required String siteId, required String clientId});

  /// Stop consuming.
  Future<void> stop();

  /// Latest snapshot — null if not yet available.
  OnyxSiteAwarenessSnapshot? get latestSnapshot;

  /// Stream of snapshots as they are produced.
  Stream<OnyxSiteAwarenessSnapshot> get snapshots;

  /// Whether the service is currently connected.
  bool get isConnected;
}
