import '../events/dispatch_event.dart';

class EventLog {
  final List<DispatchEvent> _events = [];

  void append(DispatchEvent event) {
    _events.add(event);
  }

  List<DispatchEvent> get events => List.unmodifiable(_events);
}
