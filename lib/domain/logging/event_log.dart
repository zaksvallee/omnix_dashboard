import '../events/dispatch_event.dart';

class EventLog {
  final List<DispatchEvent> _events = [];

  void append(DispatchEvent event) {
    _events.add(event);
  }

  // Canonical accessor retained for existing call sites.
  List<DispatchEvent> all() => List.unmodifiable(_events);

  // Backward-compatible accessor for older projections/tests.
  List<DispatchEvent> get events => all();
}
