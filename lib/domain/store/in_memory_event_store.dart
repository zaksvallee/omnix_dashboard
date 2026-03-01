import '../events/dispatch_event.dart';
import 'event_store.dart';

class InMemoryEventStore implements EventStore {
  final List<DispatchEvent> _events = [];
  final Set<String> _eventIds = {};
  int _currentSequence = 0;

  @override
  void append(DispatchEvent event) {
    // Duplicate protection
    if (_eventIds.contains(event.eventId)) {
      throw StateError('Duplicate eventId detected: ${event.eventId}');
    }

    _currentSequence++;

    final sequencedEvent = event.copyWithSequence(_currentSequence);

    _events.add(sequencedEvent);
    _eventIds.add(sequencedEvent.eventId);
  }

  @override
  List<DispatchEvent> allEvents() {
    return List.unmodifiable(_events);
  }

  void clear() {
    _events.clear();
    _eventIds.clear();
    _currentSequence = 0;
  }
}
