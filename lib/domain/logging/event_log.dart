import '../events/dispatch_event.dart';

class EventLog {
  final List<DispatchEvent> _events = [];

  void append(DispatchEvent event) {
    _events.add(event);
  }

  List<DispatchEvent> all() => List.unmodifiable(_events);
}
