/// Identifies the surface that deep-linked into [EventsReviewPage] so the page
/// can render an origin back-link in its scope rail.
///
/// See `events_review_page.dart` Phase 2 Option 1 (Three-Lane Forensic).
enum ZaraEventsRouteSource {
  ledger,
  aiQueue,
  dispatches,
  reports,
  governance,
  liveOps,
  navRail,
  unknown,
}

/// Callback shape for pages that deep-link into Events Review with a scoped
/// event set. [originLabel] is a short caller-supplied identifier (e.g.
/// "LED-2031-0412", "INT-DVR-4") that the scope rail renders beside the
/// back-link. Empty string means no label is available.
typedef EventsScopeCallback =
    void Function(
      List<String> eventIds,
      String? selectedEventId, {
      String originLabel,
    });
